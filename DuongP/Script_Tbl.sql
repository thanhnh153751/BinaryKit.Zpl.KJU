-- Example parameter set for your query
-- langCd='EN', crtnYy='2026', crtnMm='03', crtnYy1='2027', crtnYy2='2028', crtnYy3='2029', crtnYy4='2030'
-- copCd='C001', wkplcCd='W001', matCd='M001', vdcpCd='V001', casNo='50-00-0', alasCd='', bizCd='', matDivsCd='1'

-- =========================
-- 1) TABLES
-- =========================
DROP TABLE IF EXISTS tb_scmsb_mdlt_puch_expc_qnty_reg_m CASCADE;
DROP TABLE IF EXISTS tb_scmsb_rlb_mdp_m CASCADE;
DROP TABLE IF EXISTS tb_scmsb_rlb_sbsc_reg_req_m CASCADE;
DROP TABLE IF EXISTS tb_scmsb_rlb_sbsc_reg_plan_m CASCADE;
DROP TABLE IF EXISTS tb_scmsb_rlb_sbsc_reg_nti_m CASCADE;
DROP TABLE IF EXISTS tb_cm_request_m CASCADE;
DROP TABLE IF EXISTS tb_mm_subt_sum_matl_m CASCADE;
DROP TABLE IF EXISTS tb_rapid_cmn_c CASCADE;
DROP TABLE IF EXISTS tb_cm_matl_m CASCADE;
DROP TABLE IF EXISTS tb_scp_sup_plan_sum_m CASCADE;
DROP TABLE IF EXISTS tb_mdlt_sup_plan_sum_m CASCADE;
DROP TABLE IF EXISTS tb_mi_matl_ingt_m CASCADE;
DROP TABLE IF EXISTS tb_mi_wkplc_n CASCADE;
DROP TABLE IF EXISTS tb_mi_matl_ingt_inv_m CASCADE;
DROP TABLE IF EXISTS tb_mi_matl_ingt_n CASCADE;

CREATE TABLE tb_scmsb_mdlt_puch_expc_qnty_reg_m (
    ctry_cd                varchar(10),
    cop_cd                 varchar(20),
    mat_cd                 varchar(40),
    vdcp_cd                varchar(40),
    cas_no                 varchar(50),
    kor_recm_reg_exmp_no   varchar(100),
    kor_recm_reg_tp_cd     varchar(30),
    kor_recm_reg_exmp_dt   date,
    kor_recm_exmp_st_dt    date,
    kor_recm_exmp_end_dt   date,
    recm_reg_qty           numeric(18,5),
    recm_reg_qty_cd        varchar(30),
    hdfg_ins_yn            char(1),
    hdfg_ins_trnm_yn       char(1),
    rnd_fert_yn            char(1)
);

CREATE TABLE tb_scmsb_rlb_mdp_m (
    rlb_mdp_id             varchar(40),
    rlb_vdcp_mdp_nm        varchar(200)
);

CREATE TABLE tb_scmsb_rlb_sbsc_reg_req_m (
    subt_reg_req_doct_no   varchar(40),
    to_cop_cd              varchar(20),
    cas_no                 varchar(50),
    sbsc_reg_stp_stat_cd   varchar(20),
    use_yn                 char(1),
    purpose_cd             varchar(20),
    reg_divs_cd            varchar(1)
);

CREATE TABLE tb_scmsb_rlb_sbsc_reg_plan_m (
    subt_reg_req_doct_no   varchar(40),
    subt_reg_plan_doct_no  varchar(40)
);

CREATE TABLE tb_scmsb_rlb_sbsc_reg_nti_m (
    subt_reg_plan_doct_no  varchar(40),
    sbsc_reg_req_doc_no    varchar(40),
    reg_qty                varchar(30),
    previous_rept_no       varchar(50),
    appr_req_form_id       varchar(40)
);

CREATE TABLE tb_cm_request_m (
    request_id             varchar(40),
    system_cd              varchar(10),
    request_status_cd      varchar(20)
);

CREATE TABLE tb_mm_subt_sum_matl_m (
    chk_year               varchar(4),
    sa_comp_cd             varchar(20),
    wkplc_cd               varchar(20),
    matl_cd                varchar(40),
    vend_cd                varchar(40),
    cas_no                 varchar(50),
    mon_01                 numeric(18,5),
    mon_02                 numeric(18,5),
    mon_03                 numeric(18,5),
    mon_04                 numeric(18,5),
    mon_05                 numeric(18,5),
    mon_06                 numeric(18,5),
    mon_07                 numeric(18,5),
    mon_08                 numeric(18,5),
    mon_09                 numeric(18,5),
    mon_10                 numeric(18,5),
    mon_11                 numeric(18,5),
    mon_12                 numeric(18,5)
);

CREATE TABLE tb_rapid_cmn_c (
    cmn_gr_cd              varchar(100),
    cmn_cd                 varchar(40),
    opt_val_ctn8           varchar(10),
    opt_val_ctn10          varchar(40)
);

CREATE TABLE tb_cm_matl_m (
    matl_cd                varchar(40),
    matl_cate_cd           varchar(10)
);

CREATE TABLE tb_scp_sup_plan_sum_m (
    ver_id                 varchar(10),
    plan_yy                varchar(4),
    plnt_cd                varchar(20),
    mat_cd                 varchar(40),
    vdcp_cd                varchar(40),
    pcls_dtl_ctn           varchar(100),
    prdn_ln_cd             varchar(40),
    mdl_alas_nm            varchar(100),
    mat_gr_ctn             varchar(100),
    mon_01                 numeric(18,5),
    mon_02                 numeric(18,5),
    mon_03                 numeric(18,5),
    mon_04                 numeric(18,5),
    mon_05                 numeric(18,5),
    mon_06                 numeric(18,5),
    mon_07                 numeric(18,5),
    mon_08                 numeric(18,5),
    mon_09                 numeric(18,5),
    mon_10                 numeric(18,5),
    mon_11                 numeric(18,5),
    mon_12                 numeric(18,5)
);

CREATE TABLE tb_mdlt_sup_plan_sum_m (
    ver_id                 varchar(10),
    chk_year               varchar(4),
    sa_comp_cd             varchar(20),
    wkplc_cd               varchar(20),
    matl_cd                varchar(40),
    vend_cd                varchar(40),
    pcls_dtl_ctn           varchar(100),
    mdl_alas_nm            varchar(100),
    mat_gr_ctn             varchar(100),
    puch_expc_qty          numeric(18,5)
);

CREATE TABLE tb_mi_matl_ingt_m (
    matl_ingt_suy_no       bigint,
    lt_matl_ingt_suy_no    bigint,
    matl_cd                varchar(40),
    vend_cd                varchar(40)
);

CREATE TABLE tb_mi_wkplc_n (
    wkplc_cd               varchar(20),
    matl_ingt_suy_no       bigint
);

CREATE TABLE tb_mi_matl_ingt_inv_m (
    matl_ingt_suy_no       bigint,
    matl_cd                varchar(40),
    vend_cd                varchar(40),
    matl_cate_cd           varchar(20),
    temp_unblock_appr_no   varchar(40)
);

CREATE TABLE tb_mi_matl_ingt_n (
    matl_ingt_suy_no       bigint,
    cas_no                 varchar(50),
    en_subt_nm             varchar(200),
    subt_cont              numeric(10,4),
    k_reach_req_qty_vol    varchar(30),
    k_reach_reg_no         varchar(100)
);

-- =========================
-- 2) EXAMPLE DATA
-- =========================

-- Common codes
(opt_val_ctn10 not in talbe) =INSERT INTO tb_rapid_cmn_c (cmn_gr_cd, cmn_cd, opt_val_ctn8, opt_val_ctn10) VALUES
('CMSCM_COMPANY', 'C001', 'Y', NULL),
('CM_PLANT_DIVISION_MAPPING', 'P001', 'Y', 'C001');

-- Material master
=INSERT INTO tb_cm_matl_m (matl_cd, matl_cate_cd) VALUES
('M001', '1');

-- Vendor fallback name
==INSERT INTO tb_scmsb_rlb_mdp_m (rlb_mdp_id, rlb_vdcp_mdp_nm) VALUES
('V001', 'Vendor One');

-- Expected registration quantity source
==INSERT INTO tb_scmsb_mdlt_puch_expc_qnty_reg_m (
    ctry_cd, cop_cd, mat_cd, vdcp_cd, cas_no,
    kor_recm_reg_exmp_no, kor_recm_reg_tp_cd,
    kor_recm_reg_exmp_dt, kor_recm_exmp_st_dt, kor_recm_exmp_end_dt,
    recm_reg_qty, recm_reg_qty_cd, hdfg_ins_yn, hdfg_ins_trnm_yn, rnd_fert_yn
) VALUES (
    'KR', 'C001', 'M001', 'V001', '50-00-0',
    'KR-REACH-0001', 'TP1',
    '2025-01-15', NULL, NULL,
    1000, 'Q1', 'N', 'N', 'N'
);

-- LGES registration source (UNION path 1)
==INSERT INTO tb_cm_request_m (request_id, system_cd, request_status_cd) VALUES
('REQ1', 'MM', 'COMPLETE'),
('REQ_TMP', 'MM', 'COMPLETE');

==INSERT INTO tb_scmsb_rlb_sbsc_reg_req_m (
    subt_reg_req_doct_no, to_cop_cd, cas_no, sbsc_reg_stp_stat_cd, use_yn, purpose_cd, reg_divs_cd
) VALUES
('DOC1', 'C001', '50-00-0', NULL, 'Y', 'MP', 'N');

==INSERT INTO tb_scmsb_rlb_sbsc_reg_plan_m (subt_reg_req_doct_no, subt_reg_plan_doct_no) VALUES
('DOC1', 'PLAN1');

==INSERT INTO tb_scmsb_rlb_sbsc_reg_nti_m (
    subt_reg_plan_doct_no, sbsc_reg_req_doc_no, reg_qty, previous_rept_no, appr_req_form_id
) VALUES
('PLAN1', 'DOC1', 'Q2', NULL, 'REQ1');

-- Current year actual monthly
==INSERT INTO tb_mm_subt_sum_matl_m (
    chk_year, sa_comp_cd, wkplc_cd, matl_cd, vend_cd, cas_no,
    mon_01, mon_02, mon_03, mon_04, mon_05, mon_06, mon_07, mon_08, mon_09, mon_10, mon_11, mon_12
) VALUES
('2026', 'C001', 'W001', 'M001', 'V001', '50-00-0',
 100, 120, 130, 0, 0, 0, 0, 0, 0, 0, 0, 0);

-- Purchase plan (current + next year)
INSERT INTO tb_scp_sup_plan_sum_m (
    ver_id, plan_yy, plnt_cd, mat_cd, vdcp_cd, pcls_dtl_ctn, prdn_ln_cd, mdl_alas_nm, mat_gr_ctn,
    mon_01, mon_02, mon_03, mon_04, mon_05, mon_06, mon_07, mon_08, mon_09, mon_10, mon_11, mon_12
) VALUES
('202603', '2026', 'P001', 'M001', 'V001', 'BIZ-01', 'LINE-01', 'ALAS-01', 'GRP-01',
 10,10,10,10,10,10,10,10,10,10,10,10),
('202603', '2027', 'P001', 'M001', 'V001', 'BIZ-01', 'LINE-01', 'ALAS-01', 'GRP-01',
 12,12,12,12,12,12,12,12,12,12,12,12);

-- Mid/long-term plan
INSERT INTO tb_mdlt_sup_plan_sum_m (
    ver_id, chk_year, sa_comp_cd, wkplc_cd, matl_cd, vend_cd, pcls_dtl_ctn, mdl_alas_nm, mat_gr_ctn, puch_expc_qty
) VALUES
('202602', '2027', 'C001', 'W001', 'M001', 'V001', 'BIZ-01', 'ALAS-01', 'GRP-01', 220),
('202602', '2028', 'C001', 'W001', 'M001', 'V001', 'BIZ-01', 'ALAS-01', 'GRP-01', 240),
('202602', '2029', 'C001', 'W001', 'M001', 'V001', 'BIZ-01', 'ALAS-01', 'GRP-01', 260),
('202602', '2030', 'C001', 'W001', 'M001', 'V001', 'BIZ-01', 'ALAS-01', 'GRP-01', 280);

-- Ingredient relation chain (rk=1 path)
INSERT INTO tb_mi_matl_ingt_m (matl_ingt_suy_no, lt_matl_ingt_suy_no, matl_cd, vend_cd) VALUES
(200, 100, 'M001', 'V001');

INSERT INTO tb_mi_wkplc_n (wkplc_cd, matl_ingt_suy_no) VALUES
('W001', 100);

INSERT INTO tb_mi_matl_ingt_inv_m (matl_ingt_suy_no, matl_cd, vend_cd, matl_cate_cd, temp_unblock_appr_no) VALUES
(100, 'M001', 'V001', 'RAW', NULL);

INSERT INTO tb_mi_matl_ingt_n (
    matl_ingt_suy_no, cas_no, en_subt_nm, subt_cont, k_reach_req_qty_vol, k_reach_reg_no
) VALUES
(100, '50-00-0', 'Formaldehyde', 50.0000, 'Q1', 'KR-REACH-0001');
