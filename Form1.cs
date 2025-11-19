using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Windows.Forms;
using System.IO;
using System.Diagnostics;
using ZplRenderer.Core.Interfaces;
using ZplRenderer.Infrastructure.Renderers;
using ZplRenderer.Config;


namespace MainAppSimulator
{
    public partial class Form1 : Form
    {
        public Form1()
        {
            InitializeComponent();
        }

        private void button1_Click(object sender, EventArgs e)
        {
            IZplRenderer renderer = new ZplRenderService();

            // Setup test paths
            string currentDir = Directory.GetCurrentDirectory();
            string currentOut = @"D:\\ZPL_Output";
            string testZplFile = Path.Combine(currentDir, "test.zpl");
            string outputDir = Path.Combine(currentOut, "output");

            TestConversion(renderer, testZplFile, Path.Combine(outputDir, "test_result"), "jpg", 203, 4, 6); //203-300-600
            

            //renderer.ConvertZplToFile("D://label//new.zpl", "D://label", "jpg");
        }



        static void TestConversion(IZplRenderer renderer, string zplFile, string outputDir, string format, int dpi, int width, int height)
        {
            try
            {

                var options = new ZplRenderOptions(dpi, width, height);
            
                renderer.ConvertZplToFile(zplFile, outputDir, format, options);

                Console.WriteLine("[INFO] Output saved to: " + outputDir);

                // List generated files
                if (Directory.Exists(outputDir))
                {
                    string[] files = Directory.GetFiles(outputDir);
                    Console.WriteLine("[INFO] Generated " + files.Length + " file(s):");
                    foreach (string file in files)
                    {
                        FileInfo fi = new FileInfo(file);
                        Console.WriteLine("  - " + Path.GetFileName(file) + " (" + (fi.Length / 1024.0).ToString("F2") + " KB)");
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine("[ERROR] " + ex.GetType().Name + ": " + ex.Message);
                if (ex.InnerException != null)
                {
                    Console.WriteLine("[INNER ERROR] " + ex.InnerException.Message);
                }
            }
        }



    }
}
