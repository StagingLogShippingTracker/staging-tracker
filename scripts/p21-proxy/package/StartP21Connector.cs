using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

namespace SlstP21Connector
{
    static class Program
    {
        [STAThread]
        static void Main()
        {
            Application.EnableVisualStyles();
            try
            {
                string dir = AppDomain.CurrentDomain.BaseDirectory;
                string envPath = Path.Combine(dir, ".env");
                string examplePath = Path.Combine(dir, ".env.example");
                string startPs1 = Path.Combine(dir, "start-proxy.ps1");

                if (!File.Exists(startPs1))
                {
                    MessageBox.Show(
                        "start-proxy.ps1 not found next to this .exe.\nUnzip the full package and run from that folder.",
                        "SLST P21 Connector",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Error);
                    return;
                }

                if (!File.Exists(envPath))
                {
                    if (File.Exists(examplePath))
                    {
                        File.Copy(examplePath, envPath);
                    }
                    MessageBox.Show(
                        "Created .env — fill in P21_USERNAME and P21_PASSWORD, then save and run this again.\n\nNotepad will open next.",
                        "SLST P21 Connector — First run",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Information);
                    Process.Start(new ProcessStartInfo
                    {
                        FileName = "notepad.exe",
                        Arguments = "\"" + envPath + "\"",
                        UseShellExecute = true
                    });
                    return;
                }

                string envText = File.ReadAllText(envPath);
                if (envText.IndexOf("your.p21.username", StringComparison.OrdinalIgnoreCase) >= 0
                    || envText.IndexOf("your_p21_password", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    MessageBox.Show(
                        ".env still has placeholder credentials.\nEdit P21_USERNAME and P21_PASSWORD, save, then run again.",
                        "SLST P21 Connector",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Warning);
                    Process.Start(new ProcessStartInfo
                    {
                        FileName = "notepad.exe",
                        Arguments = "\"" + envPath + "\"",
                        UseShellExecute = true
                    });
                    return;
                }

                var psi = new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    Arguments = "-NoProfile -ExecutionPolicy Bypass -File \"" + startPs1 + "\"",
                    WorkingDirectory = dir,
                    UseShellExecute = true
                };
                Process.Start(psi);

                MessageBox.Show(
                    "P21 proxy is starting in a PowerShell window.\n\n"
                    + "Leave that window OPEN while using Order History in the browser.\n"
                    + "Proxy: http://127.0.0.1:8787\n\n"
                    + "Site: https://staginglogshippingtracker.github.io/staging-tracker/",
                    "SLST P21 Connector",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Information);
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "SLST P21 Connector Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }
    }
}
