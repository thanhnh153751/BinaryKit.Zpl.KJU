CREATE OR REPLACE FUNCTION fn_get_vand_info_lang(
    p_vdcp_cd varchar,
    p_cop_cd varchar,
    p_lang_cd text,
    p_attr text
)
RETURNS text
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_name text;
BEGIN
    IF UPPER(COALESCE(p_attr, '')) <> 'NAME' THEN
        RETURN NULL;
    END IF;

    SELECT m.rlb_vdcp_mdp_nm
      INTO v_name
      FROM tb_scmsb_rlb_mdp_m m
     WHERE m.rlb_mdp_id = p_vdcp_cd
     LIMIT 1;

    RETURN v_name;
END;
$$;

CREATE OR REPLACE FUNCTION fn_get_cd_nm(
    p_group_cd text,
    p_code text,
    p_lang_cd text
)
RETURNS text
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    -- Generic fallback stub for code-name lookup
    RETURN COALESCE(p_code, '');
END;
$$;

CREATE OR REPLACE FUNCTION fn_get_cm_matl_name(
    p_matl_cd text,
    p_lang_cd text
)
RETURNS text
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    -- Generic fallback stub for material name lookup
    RETURN COALESCE(p_matl_cd, '');
END;
$$;

CREATE OR REPLACE FUNCTION fn_get_cm_code_attr(
    p_group_cd text,
    p_code text,
    p_attr_no integer
)
RETURNS text
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    -- Minimal behavior for this script's known usages
    IF p_group_cd = 'CMSCM_COMPANY' AND p_attr_no = 1 THEN
        RETURN 'KR';
    END IF;

    IF p_group_cd = 'MM_SBSC_REG_IFO_REG_QTY_CD' AND p_attr_no = 5 THEN
        RETURN CASE COALESCE(p_code, '')
            WHEN 'Q1' THEN '1000'
            WHEN 'Q2' THEN '10000'
            WHEN 'Q3' THEN '100000'
            WHEN 'Q4' THEN '1000000'
            ELSE NULL
        END;
    END IF;

    RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION fn_get_impn_dom_imp(
    p_sa_comp_cd text,
    p_vend_cd text
)
RETURNS text
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    -- Default to import so downstream columns are populated
    RETURN 'IMP';
END;
$$;

WITH vw_expc_qnty_reg_m AS (
            SELECT z.*
            FROM (
                SELECT ctry_cd,
                       cop_cd,
                       mat_cd,
                       vdcp_cd,
                       COALESCE(
                           fn_get_vand_info_lang(vdcp_cd, cop_cd, 'EN', 'NAME'),
                           (
                               SELECT rlb_vdcp_mdp_nm
                               FROM tb_scmsb_rlb_mdp_m
                               WHERE rlb_mdp_id = vdcp_cd
                               LIMIT 1
                           )
                       ) AS vdcp_nm,
                       cas_no,
                       kor_recm_reg_exmp_no,
                       kor_recm_reg_tp_cd,
                       fn_get_cd_nm('MI_K_REACH_CHK_CATE_CD'::varchar, kor_recm_reg_tp_cd, 'EN') AS kor_recm_reg_tp_nm,
                       COALESCE(
                           TO_CHAR(kor_recm_reg_exmp_dt, 'YYYY-MM-DD'),
                           TO_CHAR(kor_recm_exmp_st_dt, 'YYYY-MM-DD')
                               || CASE WHEN kor_recm_exmp_st_dt IS NULL THEN '' ELSE ' ~ ' END
                               || TO_CHAR(kor_recm_exmp_end_dt, 'YYYY-MM-DD')
                       ) AS kor_recm_reg_exmp_dt,
                       recm_reg_qty,
                       recm_reg_qty_cd,
                       hdfg_ins_yn,
                       rnd_fert_yn
                FROM tb_scmsb_mdlt_puch_expc_qnty_reg_m
                WHERE kor_recm_reg_exmp_no IS NOT NULL
                  AND (hdfg_ins_yn = 'N' OR (hdfg_ins_yn = 'Y' AND hdfg_ins_trnm_yn = 'Y'))
            ) z
            GROUP BY z.ctry_cd, z.cop_cd, z.mat_cd, z.vdcp_cd, z.vdcp_nm, z.cas_no, z.kor_recm_reg_exmp_no, z.kor_recm_reg_tp_cd,
                     z.kor_recm_reg_tp_nm, z.kor_recm_reg_exmp_dt, z.recm_reg_qty, z.recm_reg_qty_cd, z.hdfg_ins_yn, z.rnd_fert_yn
        ),
        vw_cm_lges_reg_sbsc AS (
            SELECT m.to_cop_cd, m.cas_no, n.reg_qty, n.previous_rept_no
            FROM tb_scmsb_rlb_sbsc_reg_req_m m
                     JOIN tb_scmsb_rlb_sbsc_reg_plan_m p ON m.subt_reg_req_doct_no = p.subt_reg_req_doct_no
                     JOIN tb_scmsb_rlb_sbsc_reg_nti_m n ON n.subt_reg_plan_doct_no = p.subt_reg_plan_doct_no
                     JOIN tb_cm_request_m a ON a.request_id = n.appr_req_form_id
            WHERE a.system_cd = 'MM'
              AND a.request_status_cd = 'COMPLETE'
              AND m.sbsc_reg_stp_stat_cd IS NULL
              AND COALESCE(m.use_yn, 'Y') = 'Y'
              AND m.purpose_cd = 'MP'

            UNION

            SELECT m.to_cop_cd, m.cas_no, n.reg_qty, n.previous_rept_no
            FROM tb_scmsb_rlb_sbsc_reg_req_m m
                     LEFT JOIN tb_scmsb_rlb_sbsc_reg_nti_m n ON m.subt_reg_req_doct_no = n.sbsc_reg_req_doc_no
            WHERE m.reg_divs_cd = 'Y'
              AND COALESCE(m.use_yn, 'Y') = 'Y'
              AND m.purpose_cd = 'MP'
        ),
        vw_subt_sum_matl_m AS (
            SELECT z.sa_comp_cd, z.wkplc_cd, z.matl_cd, z.vend_cd, SUM(z.crmm_sum) AS crmm_sum
            FROM (
                SELECT chk_year,
                       sa_comp_cd,
                       wkplc_cd,
                       matl_cd,
                       vend_cd,
                       cas_no,
                       (
                           SELECT COALESCE(matl_cate_cd, '1')
                           FROM tb_cm_matl_m
                           WHERE matl_cd = m.matl_cd
                           LIMIT 1
                       ) AS mat_divs_cd,
                       CASE
                           WHEN '01' = '03' THEN CASE
                               WHEN TO_CHAR(CURRENT_DATE, 'YYYYMMDD') <= '2026' || '03' || '12' THEN 0
                               ELSE mon_01
                               END
                           WHEN '02' = '03' THEN CASE
                               WHEN TO_CHAR(CURRENT_DATE, 'YYYYMMDD') <= '2026' || '03' || '12' THEN (mon_01)
                               ELSE (mon_01 + mon_02)
                               END
                           WHEN '03' = '03' THEN CASE
                               WHEN TO_CHAR(CURRENT_DATE, 'YYYYMMDD') <= '2026' || '03' || '12' THEN (mon_01 + mon_02)
                               ELSE (mon_01 + mon_02 + mon_03)
                               END
                           WHEN '04' = '03' THEN CASE
                               WHEN TO_CHAR(CURRENT_DATE, 'YYYYMMDD') <= '2026' || '03' || '12' THEN (mon_01 + mon_02 + mon_03)
                               ELSE (mon_01 + mon_02 + mon_03 + mon_04)
                               END
                           WHEN '05' = '03' THEN CASE
                               WHEN TO_CHAR(CURRENT_DATE, 'YYYYMMDD') <= '2026' || '03' || '12' THEN (mon_01 + mon_02 + mon_03 + mon_04)
                               ELSE (mon_01 + mon_02 + mon_03 + mon_04 + mon_05)
                               END
                           WHEN '06' = '03' THEN CASE
                               WHEN TO_CHAR(CURRENT_DATE, 'YYYYMMDD') <= '2026' || '03' || '12' THEN (mon_01 + mon_02 + mon_03 + mon_04 + mon_05)
                               ELSE (mon_01 + mon_02 + mon_03 + mon_04 + mon_05 + mon_06)
                               END
                           WHEN '07' = '03' THEN CASE
                               WHEN TO_CHAR(CURRENT_DATE, 'YYYYMMDD') <= '2026' || '03' || '12' THEN (mon_01 + mon_02 + mon_03 + mon_04 + mon_05 + mon_06)
                               ELSE (mon_01 + mon_02 + mon_03 + mon_04 + mon_05 + mon_06 + mon_07)
                               END
                           WHEN '08' = '03' THEN CASE
                               WHEN TO_CHAR(CURRENT_DATE, 'YYYYMMDD') <= '2026' || '03' || '12' THEN (mon_01 + mon_02 + mon_03 + mon_04 + mon_05 + mon_06 + mon_07)
                               ELSE (mon_01 + mon_02 + mon_03 + mon_04 + mon_05 + mon_06 + mon_07 + mon_08)
                               END
                           WHEN '09' = '03' THEN CASE
                               WHEN TO_CHAR(CURRENT_DATE, 'YYYYMMDD') <= '2026' || '03' || '12' THEN (mon_01 + mon_02 + mon_03 + mon_04 + mon_05 + mon_06 + mon_07 + mon_08)
                               ELSE (mon_01 + mon_02 + mon_03 + mon_04 + mon_05 + mon_06 + mon_07 + mon_08 + mon_09)
                               END
                           WHEN '10' = '03' THEN CASE
                               WHEN TO_CHAR(CURRENT_DATE, 'YYYYMMDD') <= '2026' || '03' || '12' THEN (mon_01 + mon_02 + mon_03 + mon_04 + mon_05 + mon_06 + mon_07 + mon_08 + mon_09)
                               ELSE (mon_01 + mon_02 + mon_03 + mon_04 + mon_05 + mon_06 + mon_07 + mon_08 + mon_09 + mon_10)
                               END
                           WHEN '11' = '03' THEN CASE
                               WHEN TO_CHAR(CURRENT_DATE, 'YYYYMMDD') <= '2026' || '03' || '12' THEN (mon_01 + mon_02 + mon_03 + mon_04 + mon_05 + mon_06 + mon_07 + mon_08 + mon_09 + mon_10)
                               ELSE (mon_01 + mon_02 + mon_03 + mon_04 + mon_05 + mon_06 + mon_07 + mon_08 + mon_09 + mon_10 + mon_11)
                               END
                           WHEN '12' = '03' THEN CASE
                               WHEN TO_CHAR(CURRENT_DATE, 'YYYYMMDD') <= '2026' || '03' || '12' THEN (mon_01 + mon_02 + mon_03 + mon_04 + mon_05 + mon_06 + mon_07 + mon_08 + mon_09 + mon_10 + mon_11)
                               ELSE (mon_01 + mon_02 + mon_03 + mon_04 + mon_05 + mon_06 + mon_07 + mon_08 + mon_09 + mon_10 + mon_11 + mon_12)
                               END
                           ELSE 0
                           END AS crmm_sum
                FROM tb_mm_subt_sum_matl_m m
                         JOIN (
                    SELECT cmn_cd
                    FROM tb_rapid_cmn_c
                    WHERE cmn_gr_cd = 'CMSCM_COMPANY'
                      AND opt_val_ctn8 = 'Y'
                ) cm ON m.sa_comp_cd = cm.cmn_cd
                WHERE m.chk_year = '2026'
            ) z
            WHERE z.mat_divs_cd = '1'
            GROUP BY z.sa_comp_cd, z.wkplc_cd, z.matl_cd, z.vend_cd
        ),
        vw_cm_purc_plan_m AS (
            SELECT z.sa_comp_cd, z.wkplc_cd, z.matl_cd, z.vend_cd, z.pcls_dtl_ctn, z.prdn_ln_cd, z.mdl_alas_nm, z.mat_gr_ctn,
                   SUM(CASE WHEN z.plan_year = '2026' THEN z.crmm_expc_sum ELSE 0 END) AS crmm_expc_sum,
                   SUM(CASE WHEN z.plan_year = '2027' THEN z.n1_sum ELSE 0 END) AS n1_sum
            FROM (
                SELECT a.plan_yy AS plan_year,
                       b.opt_val_ctn10 AS sa_comp_cd,
                       (
                           SELECT opt_val_ctn10
                           FROM tb_rapid_cmn_c
                           WHERE cmn_gr_cd = 'CM_PLANT_DIVISION_MAPPING'
                             AND cmn_cd = a.plnt_cd
                           LIMIT 1
                       ) AS wkplc_cd,
                       a.plnt_cd AS plant_cd,
                       a.mat_cd AS matl_cd,
                       a.vdcp_cd AS vend_cd,
                       a.pcls_dtl_ctn,
                       a.prdn_ln_cd,
                       a.mdl_alas_nm,
                       a.mat_gr_ctn,
                       (
                           SELECT COALESCE(matl_cate_cd, '1')
                           FROM tb_cm_matl_m
                           WHERE matl_cd = a.mat_cd
                           LIMIT 1
                       ) AS mat_divs_cd,
                       CASE
                           WHEN '01' = '03' THEN CASE
                               WHEN TO_CHAR(CURRENT_DATE, 'YYYYMMDD') <= '2026' || '03' || '12'
                                   THEN (mon_01 + mon_02 + mon_03 + mon_04 + mon_05 + mon_06 + mon_07 + mon_08 + mon_09 + mon_10 + mon_11 + mon_12)
                               ELSE (mon_02 + mon_03 + mon_04 + mon_05 + mon_06 + mon_07 + mon_08 + mon_09 + mon_10 + mon_11 + mon_12)
                               END
                           WHEN '02' = '03' THEN CASE
                               WHEN TO_CHAR(CURRENT_DATE, 'YYYYMMDD') <= '2026' || '03' || '12'
                                   THEN (mon_02 + mon_03 + mon_04 + mon_05 + mon_06 + mon_07 + mon_08 + mon_09 + mon_10 + mon_11 + mon_12)
                               ELSE (mon_03 + mon_04 + mon_05 + mon_06 + mon_07 + mon_08 + mon_09 + mon_10 + mon_11 + mon_12)
                               END
                           WHEN '03' = '03' THEN CASE
                               WHEN TO_CHAR(CURRENT_DATE, 'YYYYMMDD') <= '2026' || '03' || '12'
                                   THEN (mon_03 + mon_04 + mon_05 + mon_06 + mon_07 + mon_08 + mon_09 + mon_10 + mon_11 + mon_12)
                               ELSE (mon_04 + mon_05 + mon_06 + mon_07 + mon_08 + mon_09 + mon_10 + mon_11 + mon_12)
                               END
                           WHEN '04' = '03' THEN CASE
                               WHEN TO_CHAR(CURRENT_DATE, 'YYYYMMDD') <= '2026' || '03' || '12'
                                   THEN (mon_04 + mon_05 + mon_06 + mon_07 + mon_08 + mon_09 + mon_10 + mon_11 + mon_12)
                               ELSE (mon_05 + mon_06 + mon_07 + mon_08 + mon_09 + mon_10 + mon_11 + mon_12)
                               END
                           WHEN '05' = '03' THEN CASE
                               WHEN TO_CHAR(CURRENT_DATE, 'YYYYMMDD') <= '2026' || '03' || '12'
                                   THEN (mon_05 + mon_06 + mon_07 + mon_08 + mon_09 + mon_10 + mon_11 + mon_12)
                               ELSE (mon_06 + mon_07 + mon_08 + mon_09 + mon_10 + mon_11 + mon_12)
                               END
                           WHEN '06' = '03' THEN CASE
                               WHEN TO_CHAR(CURRENT_DATE, 'YYYYMMDD') <= '2026' || '03' || '12'
                                   THEN (mon_06 + mon_07 + mon_08 + mon_09 + mon_10 + mon_11 + mon_12)
                               ELSE (mon_07 + mon_08 + mon_09 + mon_10 + mon_11 + mon_12)
                               END
                           WHEN '07' = '03' THEN CASE
                               WHEN TO_CHAR(CURRENT_DATE, 'YYYYMMDD') <= '2026' || '03' || '12'
                                   THEN (mon_07 + mon_08 + mon_09 + mon_10 + mon_11 + mon_12)
                               ELSE (mon_08 + mon_09 + mon_10 + mon_11 + mon_12)
                               END
                           WHEN '08' = '03' THEN CASE
                               WHEN TO_CHAR(CURRENT_DATE, 'YYYYMMDD') <= '2026' || '03' || '12'
                                   THEN (mon_08 + mon_09 + mon_10 + mon_11 + mon_12)
                               ELSE (mon_09 + mon_10 + mon_11 + mon_12)
                               END
                           WHEN '09' = '03' THEN CASE
                               WHEN TO_CHAR(CURRENT_DATE, 'YYYYMMDD') <= '2026' || '03' || '12'
                                   THEN (mon_09 + mon_10 + mon_11 + mon_12)
                               ELSE (mon_10 + mon_11 + mon_12)
                               END
                           WHEN '10' = '03' THEN CASE
                               WHEN TO_CHAR(CURRENT_DATE, 'YYYYMMDD') <= '2026' || '03' || '12'
                                   THEN (mon_10 + mon_11 + mon_12)
                               ELSE (mon_11 + mon_12)
                               END
                           WHEN '11' = '03' THEN CASE
                               WHEN TO_CHAR(CURRENT_DATE, 'YYYYMMDD') <= '2026' || '03' || '12'
                                   THEN (mon_11 + mon_12)
                               ELSE (mon_12)
                               END
                           WHEN '12' = '03' THEN CASE
                               WHEN TO_CHAR(CURRENT_DATE, 'YYYYMMDD') <= '2026' || '03' || '12' THEN (mon_12)
                               ELSE 0
                               END
                           ELSE 0
                           END AS crmm_expc_sum,
                       (mon_01 + mon_02 + mon_03 + mon_04 + mon_05 + mon_06 + mon_07 + mon_08 + mon_09 + mon_10 + mon_11 + mon_12) AS n1_sum
                FROM tb_scp_sup_plan_sum_m a
                         JOIN (
                    SELECT cmn_cd, opt_val_ctn10
                    FROM tb_rapid_cmn_c
                    WHERE cmn_gr_cd = 'CM_PLANT_DIVISION_MAPPING'
                      AND opt_val_ctn8 = 'Y'
                ) b ON a.plnt_cd = b.cmn_cd
                         JOIN (
                    SELECT cmn_cd
                    FROM tb_rapid_cmn_c
                    WHERE cmn_gr_cd = 'CMSCM_COMPANY'
                      AND opt_val_ctn8 = 'Y'
                ) cm ON b.opt_val_ctn10 = cm.cmn_cd
                WHERE a.ver_id = '2026' || '03'
                  AND a.plan_yy IN ('2026', '2027')
                  AND a.vdcp_cd IS NOT NULL
            ) z
            WHERE z.mat_divs_cd = '1'
            GROUP BY z.sa_comp_cd, z.wkplc_cd, z.matl_cd, z.vend_cd, z.pcls_dtl_ctn, z.prdn_ln_cd, z.mdl_alas_nm, z.mat_gr_ctn
        ),
        vw_cm_purc_mdlt_plan_m AS (
            SELECT w.sa_comp_cd, w.wkplc_cd, w.matl_cd, w.vend_cd, w.pcls_dtl_ctn, w.mdl_alas_nm, w.mat_gr_ctn,
                   SUM(CASE WHEN w.chk_year = '2027' THEN w.puch_expc_qty ELSE 0 END) AS n1_mdlt_sum,
                   SUM(CASE WHEN w.chk_year = '2028' THEN w.puch_expc_qty ELSE 0 END) AS n2_mdlt_sum,
                   SUM(CASE WHEN w.chk_year = '2029' THEN w.puch_expc_qty ELSE 0 END) AS n3_mdlt_sum,
                   SUM(CASE WHEN w.chk_year = '2030' THEN w.puch_expc_qty ELSE 0 END) AS n4_mdlt_sum
            FROM (
                SELECT a.chk_year, a.sa_comp_cd, a.wkplc_cd, a.matl_cd, a.vend_cd, a.pcls_dtl_ctn, a.mdl_alas_nm, a.mat_gr_ctn, a.puch_expc_qty,
                       (
                           SELECT COALESCE(matl_cate_cd, '1')
                           FROM tb_cm_matl_m
                           WHERE matl_cd = a.matl_cd
                           LIMIT 1
                       ) AS mat_divs_cd
                FROM tb_mdlt_sup_plan_sum_m a
                         JOIN (
                    SELECT cmn_cd
                    FROM tb_rapid_cmn_c
                    WHERE cmn_gr_cd = 'CMSCM_COMPANY'
                      AND opt_val_ctn8 = 'Y'
                ) cm ON a.sa_comp_cd = cm.cmn_cd
                WHERE a.ver_id = (
                    SELECT MAX(ver_id)
                    FROM tb_mdlt_sup_plan_sum_m
                    WHERE ver_id <= '2026' || '03'
                )
                  AND a.chk_year IN ('2027', '2028', '2029', '2030')
                  AND a.vend_cd IS NOT NULL
                  AND a.vend_cd != '-'
            ) w
            WHERE w.mat_divs_cd = '1'
            GROUP BY w.sa_comp_cd, w.wkplc_cd, w.matl_cd, w.vend_cd, w.pcls_dtl_ctn, w.mdl_alas_nm, w.mat_gr_ctn
        ),
        vw_cm_purc_plan_mdlt_plan AS (
            SELECT COALESCE(a.sa_comp_cd, b.sa_comp_cd) AS sa_comp_cd,
                   COALESCE(a.wkplc_cd, b.wkplc_cd) AS wkplc_cd,
                   COALESCE(a.matl_cd, b.matl_cd) AS matl_cd,
                   COALESCE(a.vend_cd, b.vend_cd) AS vend_cd,
                   COALESCE(a.pcls_dtl_ctn, b.pcls_dtl_ctn) AS pcls_dtl_ctn,
                   a.prdn_ln_cd,
                   COALESCE(a.mdl_alas_nm, b.mdl_alas_nm) AS mdl_alas_nm,
                   COALESCE(a.mat_gr_ctn, b.mat_gr_ctn) AS mat_gr_ctn,
                   COALESCE(a.crmm_expc_sum, 0) AS crmm_expc_sum,
                   COALESCE(a.n1_sum, 0) AS n1_sum,
                   COALESCE(b.n1_mdlt_sum, 0) AS n1_mdlt_sum,
                   COALESCE(b.n2_mdlt_sum, 0) AS n2_mdlt_sum,
                   COALESCE(b.n3_mdlt_sum, 0) AS n3_mdlt_sum,
                   COALESCE(b.n4_mdlt_sum, 0) AS n4_mdlt_sum
            FROM vw_cm_purc_plan_m a
                     FULL OUTER JOIN vw_cm_purc_mdlt_plan_m b
                                     ON a.sa_comp_cd = b.sa_comp_cd
                                         AND a.wkplc_cd = b.wkplc_cd
                                         AND a.matl_cd = b.matl_cd
                                         AND a.vend_cd = b.vend_cd
                                         AND a.pcls_dtl_ctn = b.pcls_dtl_ctn
                                         AND a.mdl_alas_nm = b.mdl_alas_nm
        ),
        vw_cm_sum_matl_purc_plan_mdlt_plan AS (
            SELECT z.sa_comp_cd, z.wkplc_cd, z.matl_cd, z.vend_cd, z.pcls_dtl_ctn, z.prdn_ln_cd, z.mdl_alas_nm, z.mat_gr_ctn,
                   (
                       SELECT COALESCE(matl_cate_cd, '1')
                       FROM tb_cm_matl_m
                       WHERE matl_cd = z.matl_cd
                       LIMIT 1
                   ) AS mat_divs_cd,
                   SUM(z.crmm_sum) OVER (PARTITION BY z.sa_comp_cd, z.wkplc_cd, z.matl_cd, z.vend_cd) AS crmm_sum,
                   SUM(z.crmm_expc_sum) OVER (PARTITION BY z.sa_comp_cd, z.wkplc_cd, z.matl_cd, z.vend_cd) AS crmm_expc_sum,
                   SUM(z.n1_sum) OVER (PARTITION BY z.sa_comp_cd, z.wkplc_cd, z.matl_cd, z.vend_cd) AS n1_sum,
                   SUM(z.n1_mdlt_sum) OVER (PARTITION BY z.sa_comp_cd, z.wkplc_cd, z.matl_cd, z.vend_cd) AS n1_mdlt_sum,
                   SUM(z.n2_mdlt_sum) OVER (PARTITION BY z.sa_comp_cd, z.wkplc_cd, z.matl_cd, z.vend_cd) AS n2_mdlt_sum,
                   SUM(z.n3_mdlt_sum) OVER (PARTITION BY z.sa_comp_cd, z.wkplc_cd, z.matl_cd, z.vend_cd) AS n3_mdlt_sum,
                   SUM(z.n4_mdlt_sum) OVER (PARTITION BY z.sa_comp_cd, z.wkplc_cd, z.matl_cd, z.vend_cd) AS n4_mdlt_sum
            FROM (
                SELECT COALESCE(a.sa_comp_cd, b.sa_comp_cd) AS sa_comp_cd,
                       COALESCE(a.wkplc_cd, b.wkplc_cd) AS wkplc_cd,
                       COALESCE(a.matl_cd, b.matl_cd) AS matl_cd,
                       COALESCE(a.vend_cd, b.vend_cd) AS vend_cd,
                       a.pcls_dtl_ctn,
                       a.prdn_ln_cd,
                       a.mdl_alas_nm,
                       a.mat_gr_ctn,
                       COALESCE(b.crmm_sum, 0) AS crmm_sum,
                       COALESCE(a.crmm_expc_sum, 0) AS crmm_expc_sum,
                       COALESCE(a.n1_sum, 0) AS n1_sum,
                       COALESCE(a.n1_mdlt_sum, 0) AS n1_mdlt_sum,
                       COALESCE(a.n2_mdlt_sum, 0) AS n2_mdlt_sum,
                       COALESCE(a.n3_mdlt_sum, 0) AS n3_mdlt_sum,
                       COALESCE(a.n4_mdlt_sum, 0) AS n4_mdlt_sum
                FROM vw_cm_purc_plan_mdlt_plan a
                         FULL OUTER JOIN vw_subt_sum_matl_m b
                                         ON a.sa_comp_cd = b.sa_comp_cd
                                             AND a.wkplc_cd = b.wkplc_cd
                                             AND a.matl_cd = b.matl_cd
                                             AND a.vend_cd = b.vend_cd
            ) z
        ),
        vw_expc_reg_crtn_ingt_inv AS (
            SELECT x.*,
                   n.cas_no,
                   n.en_subt_nm AS sbsc_nm,
                   n.subt_cont,
                   CASE
                       WHEN n.k_reach_req_qty_vol IS NOT NULL AND POSITION('MI' IN n.k_reach_req_qty_vol) = 0
                           THEN n.k_reach_req_qty_vol
                       ELSE (
                           SELECT recm_reg_qty_cd
                           FROM vw_expc_qnty_reg_m v
                           WHERE v.cop_cd = x.sa_comp_cd
                             AND v.mat_cd = x.matl_cd
                             AND v.vdcp_cd = x.vend_cd
                             AND v.cas_no = n.cas_no
                           LIMIT 1
                       )
                       END AS excp_reg_qty_cd,
                   CASE
                       WHEN n.k_reach_req_qty_vol IS NOT NULL AND POSITION('MI' IN n.k_reach_req_qty_vol) = 0
                           THEN fn_get_cd_nm('MM_SBSC_REG_IFO_REG_QTY_CD'::varchar, n.k_reach_req_qty_vol, 'EN')
                       ELSE fn_get_cd_nm(
                           'MI_K_REACH_REQ_QTY_VOL'::varchar,
                           (
                               SELECT recm_reg_qty_cd
                               FROM vw_expc_qnty_reg_m v
                               WHERE v.cop_cd = x.sa_comp_cd
                                 AND v.mat_cd = x.matl_cd
                                 AND v.vdcp_cd = x.vend_cd
                                 AND v.cas_no = n.cas_no
                               LIMIT 1
                           ),
                           'EN'
                            )
                       END AS excp_reg_qty_nm,
                   CASE
                       WHEN n.k_reach_req_qty_vol IS NOT NULL AND POSITION('MI' IN n.k_reach_req_qty_vol) = 0
                          THEN NULLIF(fn_get_cm_code_attr('MM_SBSC_REG_IFO_REG_QTY_CD', n.k_reach_req_qty_vol, 5), '')::numeric
                      ELSE (
                          SELECT recm_reg_qty
                           FROM vw_expc_qnty_reg_m v
                           WHERE v.cop_cd = x.sa_comp_cd
                             AND v.mat_cd = x.matl_cd
                             AND v.vdcp_cd = x.vend_cd
                             AND v.cas_no = n.cas_no
                           LIMIT 1
                       )
                       END AS excp_reg_qty,
                   CASE
                       WHEN n.k_reach_req_qty_vol IS NOT NULL AND POSITION('MI' IN n.k_reach_req_qty_vol) = 0
                           THEN n.k_reach_reg_no
                       ELSE (
                           SELECT kor_recm_reg_exmp_no
                           FROM vw_expc_qnty_reg_m v
                           WHERE v.cop_cd = x.sa_comp_cd
                             AND v.mat_cd = x.matl_cd
                             AND v.vdcp_cd = x.vend_cd
                             AND v.cas_no = n.cas_no
                             AND v.kor_recm_reg_exmp_no != '미완료'
                           LIMIT 1
                       )
                       END AS k_reach_reg_no
            FROM (
                SELECT *
                FROM (
                    SELECT ROW_NUMBER() OVER (PARTITION BY z.sa_comp_cd, z.wkplc_cd, z.matl_cd, z.vend_cd ORDER BY z.rk, z.matl_ingt_suy_no DESC) AS frk,
                           z.*
                    FROM (
                        SELECT 1 AS rk,
                               b.matl_ingt_suy_no,
                               m.sa_comp_cd,
                               m.wkplc_cd,
                               m.matl_cd,
                               m.vend_cd,
                               fn_get_cm_matl_name(m.matl_cd, 'EN') AS mat_nm
                        FROM vw_cm_sum_matl_purc_plan_mdlt_plan m
                                 JOIN tb_mi_matl_ingt_m a ON m.matl_cd = a.matl_cd AND m.vend_cd = a.vend_cd
                                 JOIN tb_mi_wkplc_n b ON m.wkplc_cd = b.wkplc_cd AND a.lt_matl_ingt_suy_no = b.matl_ingt_suy_no
                                 JOIN tb_mi_matl_ingt_inv_m c ON b.matl_ingt_suy_no = c.matl_ingt_suy_no
                        WHERE c.matl_cate_cd != 'PROD'

                        UNION ALL

                        SELECT 2 AS rk,
                               a.matl_ingt_suy_no,
                               m.sa_comp_cd,
                               m.wkplc_cd,
                               m.matl_cd,
                               m.vend_cd,
                               fn_get_cm_matl_name(m.matl_cd, 'EN') AS mat_nm
                        FROM vw_cm_sum_matl_purc_plan_mdlt_plan m
                                 JOIN tb_mi_matl_ingt_inv_m a ON m.matl_cd = a.matl_cd AND m.vend_cd = a.vend_cd
                                 JOIN tb_mi_wkplc_n b ON m.wkplc_cd = b.wkplc_cd AND a.matl_ingt_suy_no = b.matl_ingt_suy_no
                                 JOIN tb_cm_request_m c ON a.temp_unblock_appr_no = c.request_id
                        WHERE c.request_status_cd = 'COMPLETE'
                          AND a.matl_cate_cd != 'PROD'
                          AND NOT EXISTS (
                            SELECT 1
                            FROM tb_mi_matl_ingt_m m2
                            WHERE m2.lt_matl_ingt_suy_no = a.matl_ingt_suy_no
                        )
                    ) z
                             JOIN tb_cm_matl_m y ON z.matl_cd = y.matl_cd
                    WHERE COALESCE(y.matl_cate_cd, '1') = '1'
                ) x1
                WHERE x1.frk = 1
            ) x
                     JOIN tb_mi_matl_ingt_n n ON x.matl_ingt_suy_no = n.matl_ingt_suy_no
            WHERE n.cas_no IS NOT NULL
        )
        SELECT y.*,
               CASE WHEN y.excp_reg_qty IS NULL THEN NULL ELSE ROUND(COALESCE(y.n_sum * 100 / NULLIF(y.excp_reg_qty, 0), 0), 2) END AS n_excp_per,
               CASE WHEN y.excp_reg_qty IS NULL THEN NULL ELSE ROUND(COALESCE(y.n1_sum * 100 / NULLIF(y.excp_reg_qty, 0), 0), 2) END AS n1_excp_per,
               CASE WHEN y.excp_reg_qty IS NULL THEN NULL ELSE ROUND(COALESCE(y.n2_mdlt_sum * 100 / NULLIF(y.excp_reg_qty, 0), 0), 2) END AS n2_excp_per,
               CASE WHEN y.excp_reg_qty IS NULL THEN NULL ELSE ROUND(COALESCE(y.n3_mdlt_sum * 100 / NULLIF(y.excp_reg_qty, 0), 0), 2) END AS n3_excp_per,
               CASE WHEN y.excp_reg_qty IS NULL THEN NULL ELSE ROUND(COALESCE(y.n4_mdlt_sum * 100 / NULLIF(y.excp_reg_qty, 0), 0), 2) END AS n4_excp_per,
               CASE
                   WHEN y.lges_reg_qty IS NULL THEN NULL
                   WHEN y.excp_reg_qty IS NOT NULL AND (y.n_sum - y.excp_reg_qty) > 0
                       THEN ROUND(COALESCE((y.n_sum - y.excp_reg_qty) * 100 / NULLIF(y.lges_reg_qty::numeric, 0), 0), 2)
                   WHEN y.excp_reg_qty IS NULL AND y.lges_reg_qty::numeric > 0
                       THEN ROUND(COALESCE(y.n_sum * 100 / NULLIF(y.lges_reg_qty::numeric, 0), 0), 2)
                   ELSE 0
                   END AS n_lges_per,
               CASE
                   WHEN y.lges_reg_qty IS NULL THEN NULL
                   WHEN y.excp_reg_qty IS NOT NULL AND (y.n1_sum - y.excp_reg_qty) > 0
                       THEN ROUND(COALESCE((y.n1_sum - y.excp_reg_qty) * 100 / NULLIF(y.lges_reg_qty::numeric, 0), 0), 2)
                   WHEN y.excp_reg_qty IS NULL AND y.lges_reg_qty::numeric > 0
                       THEN ROUND(COALESCE(y.n1_sum * 100 / NULLIF(y.lges_reg_qty::numeric, 0), 0), 2)
                   ELSE 0
                   END AS n1_lges_per,
               CASE
                   WHEN y.lges_reg_qty IS NULL THEN NULL
                   WHEN y.excp_reg_qty IS NOT NULL AND (y.n2_mdlt_sum - y.excp_reg_qty) > 0
                       THEN ROUND(COALESCE((y.n2_mdlt_sum - y.excp_reg_qty) * 100 / NULLIF(y.lges_reg_qty::numeric, 0), 0), 2)
                   WHEN y.excp_reg_qty IS NULL AND y.lges_reg_qty::numeric > 0
                       THEN ROUND(COALESCE(y.n2_mdlt_sum * 100 / NULLIF(y.lges_reg_qty::numeric, 0), 0), 2)
                   ELSE 0
                   END AS n2_lges_per,
               CASE
                   WHEN y.lges_reg_qty IS NULL THEN NULL
                   WHEN y.excp_reg_qty IS NOT NULL AND (y.n3_mdlt_sum - y.excp_reg_qty) > 0
                       THEN ROUND(COALESCE((y.n3_mdlt_sum - y.excp_reg_qty) * 100 / NULLIF(y.lges_reg_qty::numeric, 0), 0), 2)
                   WHEN y.excp_reg_qty IS NULL AND y.lges_reg_qty::numeric > 0
                       THEN ROUND(COALESCE(y.n3_mdlt_sum * 100 / NULLIF(y.lges_reg_qty::numeric, 0), 0), 2)
                   ELSE 0
                   END AS n3_lges_per,
               CASE
                   WHEN y.lges_reg_qty IS NULL THEN NULL
                   WHEN y.excp_reg_qty IS NOT NULL AND (y.n4_mdlt_sum - y.excp_reg_qty) > 0
                       THEN ROUND(COALESCE((y.n4_mdlt_sum - y.excp_reg_qty) * 100 / NULLIF(y.lges_reg_qty::numeric, 0), 0), 2)
                   WHEN y.excp_reg_qty IS NULL AND y.lges_reg_qty::numeric > 0
                       THEN ROUND(COALESCE(y.n4_mdlt_sum * 100 / NULLIF(y.lges_reg_qty::numeric, 0), 0), 2)
                   ELSE 0
                   END AS n4_lges_per
        FROM (
                 SELECT z.ctry_cd,
                        z.sa_comp_cd,
                        fn_get_cd_nm('CMSCM_COMPANY'::varchar, z.sa_comp_cd, 'EN') AS sa_comp_nm,
                        z.wkplc_cd,
                        fn_get_cd_nm('SM_STOCK_WKPLC_CD'::varchar, z.wkplc_cd, 'EN') AS wkplc_nm,
                        z.prdn_ln_cd,
                        z.mdl_alas_nm,
                        z.pcls_dtl_ctn,
                        fn_get_cm_matl_name(z.matl_cd, 'EN') AS mat_nm,
                        z.matl_cd AS mat_cd,
                        z.mat_gr_ctn,
                        z.mat_divs_cd,
                        fn_get_cd_nm('MATL_CATEGORY_CD'::varchar, z.mat_divs_cd, 'EN') AS mat_divs_nm,
                        fn_get_vand_info_lang(z.vend_cd, z.sa_comp_cd, 'EN', 'NAME') AS vdcp_nm,
                        z.vend_cd,
                        z.ord_type_cd,
                        fn_get_cd_nm('SM_ORD_TYPE_CD'::varchar, z.ord_type_cd, 'EN') AS impn_dom_nm,
                        z.cas_no,
                        z.sbsc_nm,
                        z.subt_cont,
                        z.k_reach_reg_no,
                        z.matl_ingt_suy_no,
                        ROUND(z.crmm_sum + z.crmm_expc_sum, 5) AS n_sum,
                        ROUND(z.n1_sum, 5) AS n1_sum,
                        ROUND(z.n2_mdlt_sum, 5) AS n2_mdlt_sum,
                        ROUND(z.n3_mdlt_sum, 5) AS n3_mdlt_sum,
                        ROUND(z.n4_mdlt_sum, 5) AS n4_mdlt_sum,
                        GREATEST(
                            ROUND(z.crmm_sum + z.crmm_expc_sum, 5),
                            ROUND(z.n1_sum, 5),
                            ROUND(z.n2_mdlt_sum, 5),
                            ROUND(z.n3_mdlt_sum, 5),
                            ROUND(z.n4_mdlt_sum, 5)
                        ) AS max_qnty,
                        z.excp_reg_qty_cd,
                        COALESCE(z.excp_reg_qty_nm, z.excp_reg_qty::text) AS excp_reg_qty_nm,
                        z.excp_reg_qty,
                        CASE WHEN z.ord_type_cd = 'DOM' THEN NULL ELSE CASE WHEN z.lges_reg_cnt > 1 THEN 'ERROR' ELSE z.lges_reg_qty_cd END END AS lges_reg_qty_cd,
                        CASE WHEN z.ord_type_cd = 'DOM' THEN NULL ELSE CASE WHEN z.lges_reg_cnt > 1 THEN 'ERROR' ELSE z.lges_reg_qty_nm END END AS lges_reg_qty_nm,
                        CASE WHEN z.ord_type_cd = 'DOM' THEN NULL ELSE CASE WHEN z.lges_reg_cnt > 1 THEN NULL ELSE z.lges_reg_qty END END AS lges_reg_qty,
                        z.lges_reg_cnt
                 FROM (
                          SELECT fn_get_cm_code_attr('CMSCM_COMPANY', m.sa_comp_cd, 1) AS ctry_cd,
                                 m.sa_comp_cd,
                                 m.wkplc_cd,
                                 m.matl_cd,
                                 m.vend_cd,
                                 m.pcls_dtl_ctn,
                                 m.prdn_ln_cd,
                                 m.mdl_alas_nm,
                                 m.mat_gr_ctn,
                                 m.mat_divs_cd,
                                 fn_get_impn_dom_imp(m.sa_comp_cd, m.vend_cd) AS ord_type_cd,
                                 a.matl_ingt_suy_no,
                                 a.cas_no,
                                 a.sbsc_nm,
                                 a.subt_cont,
                                 (m.crmm_sum * COALESCE(a.subt_cont, 100) / 100) AS crmm_sum,
                                 (m.crmm_expc_sum * COALESCE(a.subt_cont, 100) / 100) / 1000 AS crmm_expc_sum,
                                 CASE
                                     WHEN (m.n1_sum * COALESCE(a.subt_cont, 100) / 100) / 1000 >= (m.n1_mdlt_sum * COALESCE(a.subt_cont, 100) / 100)
                                         THEN (m.n1_sum * COALESCE(a.subt_cont, 100) / 100) / 1000
                                     ELSE (m.n1_mdlt_sum * COALESCE(a.subt_cont, 100) / 100)
                                     END AS n1_sum,
                                 (m.n1_mdlt_sum * COALESCE(a.subt_cont, 100) / 100) AS n1_mdlt_sum,
                                 (m.n2_mdlt_sum * COALESCE(a.subt_cont, 100) / 100) AS n2_mdlt_sum,
                                 (m.n3_mdlt_sum * COALESCE(a.subt_cont, 100) / 100) AS n3_mdlt_sum,
                                 (m.n4_mdlt_sum * COALESCE(a.subt_cont, 100) / 100) AS n4_mdlt_sum,
                                 a.k_reach_reg_no,
                                 a.excp_reg_qty_cd,
                                 a.excp_reg_qty_nm,
                                 a.excp_reg_qty,
                                 (
                                     SELECT reg_qty
                                     FROM vw_cm_lges_reg_sbsc
                                     WHERE to_cop_cd = m.sa_comp_cd
                                       AND cas_no = a.cas_no
                                     LIMIT 1
                                 ) AS lges_reg_qty_cd,
                                 (
                                     SELECT CASE
                                                WHEN previous_rept_no IS NULL
                                                    THEN fn_get_cd_nm('MM_SBSC_REG_IFO_REG_QTY_CD'::varchar, reg_qty, 'EN')
                                                ELSE previous_rept_no
                                         END
                                     FROM vw_cm_lges_reg_sbsc
                                     WHERE to_cop_cd = m.sa_comp_cd
                                       AND cas_no = a.cas_no
                                     LIMIT 1
                                 ) AS lges_reg_qty_nm,
                                 (
                                     SELECT CASE
                                                WHEN previous_rept_no IS NULL
                                                    THEN fn_get_cm_code_attr('MM_SBSC_REG_IFO_REG_QTY_CD', reg_qty, 5)
                                                ELSE previous_rept_no
                                         END
                                     FROM vw_cm_lges_reg_sbsc
                                     WHERE to_cop_cd = m.sa_comp_cd
                                       AND cas_no = a.cas_no
                                     LIMIT 1
                                 ) AS lges_reg_qty,
                                 (
                                     SELECT COUNT(*)
                                     FROM vw_cm_lges_reg_sbsc
                                     WHERE to_cop_cd = m.sa_comp_cd
                                       AND cas_no = a.cas_no
                                 ) AS lges_reg_cnt
                          FROM vw_cm_sum_matl_purc_plan_mdlt_plan m
                                   LEFT JOIN vw_expc_reg_crtn_ingt_inv a
                                             ON m.sa_comp_cd = a.sa_comp_cd
                                                 AND m.wkplc_cd = a.wkplc_cd
                                                 AND m.matl_cd = a.matl_cd
                                                 AND m.vend_cd = a.vend_cd
                          WHERE m.sa_comp_cd IN (
                              SELECT TRIM(item)
                              FROM unnest(string_to_array(COALESCE('C001', ''), ',')) AS item
                          )
                            AND m.wkplc_cd = 'W001'
                            AND m.matl_cd = 'M001'
                            AND m.vend_cd = 'V001'
                            AND a.cas_no = '50-00-0'
                            AND m.mdl_alas_nm LIKE '%' || COALESCE('', '') || '%'
                            AND m.pcls_dtl_ctn LIKE '%' || COALESCE('', '') || '%'
                            AND m.mat_divs_cd = '1'
                      ) z
             ) y
        WHERE (y.n_sum > 0 OR y.n1_sum > 0 OR y.n2_mdlt_sum > 0 OR y.n3_mdlt_sum > 0 OR y.n4_mdlt_sum > 0)
        ORDER BY y.sa_comp_cd, y.wkplc_cd, y.mat_cd, y.vend_cd, y.pcls_dtl_ctn, y.prdn_ln_cd, y.mdl_alas_nm, y.cas_no
;
