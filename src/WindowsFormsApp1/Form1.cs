using BinaryKits.Zpl.Viewer;
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace WindowsFormsApp1
{
    public partial class Form1 : Form
    {
        public Form1()
        {
            InitializeComponent();
        }

        private void textBox1_TextChanged(object sender, EventArgs e)
        {

        }

        private void button1_Click(object sender, EventArgs e)
        {
            IPrinterStorage printerStorage = new PrinterStorage();
            var drawer = new ZplElementDrawer(printerStorage);

            var analyzer = new ZplAnalyzer(printerStorage);
            var analyzeInfo = analyzer.Analyze(textBox1.Text);

            foreach (var labelInfo in analyzeInfo.LabelInfos)
            {
                var imageData = drawer.Draw(labelInfo.ZplElements);
                File.WriteAllBytes("label.png", imageData);
            }
        }
    }
}
