using System;
using System.Diagnostics;
using System.IO;
using System.Text;

namespace StyleBertVITS2Launcher
{
    internal static class Program
    {
        private static void Pause()
        {
            Console.WriteLine();
            Console.WriteLine("Nhan phim bat ky de thoat...");
            try { Console.ReadKey(true); } catch { }
        }

        private static int Main(string[] args)
        {
            try { Console.OutputEncoding = Encoding.UTF8; } catch { }

            string root = AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\');
            Directory.SetCurrentDirectory(root);

            Console.WriteLine();
            Console.WriteLine("========================================");
            Console.WriteLine("  Style-Bert-VITS2 - Portable");
            Console.WriteLine("========================================");
            Console.WriteLine();

            string python = Path.Combine(root, "runtime", "python", "python.exe");
            if (!File.Exists(python))
            {
                Console.WriteLine("[LOI] Khong tim thay runtime:");
                Console.WriteLine("      " + python);
                Console.WriteLine("      Hay giu nguyen cau truc thu muc khi chep sang may khac.");
                Pause();
                return 1;
            }

            if (!File.Exists(Path.Combine(root, "app.py")))
            {
                Console.WriteLine("[LOI] Khong tim thay app.py trong: " + root);
                Pause();
                return 1;
            }

            var psi = new ProcessStartInfo();
            psi.FileName = python;
            psi.WorkingDirectory = root;
            psi.UseShellExecute = false;
            psi.EnvironmentVariables["PYTHONIOENCODING"] = "utf-8";
            psi.EnvironmentVariables["PYTHONUTF8"] = "1";
            psi.EnvironmentVariables["PYTHONUNBUFFERED"] = "1";
            psi.EnvironmentVariables["HF_HUB_OFFLINE"] = "1";
            psi.EnvironmentVariables["TRANSFORMERS_OFFLINE"] = "1";

            var sb = new StringBuilder("-u app.py");
            foreach (string a in args)
            {
                sb.Append(' ');
                sb.Append(a);
            }
            psi.Arguments = sb.ToString();

            Console.WriteLine("Thu muc : " + root);
            Console.WriteLine("Lenh    : python.exe " + psi.Arguments);
            Console.WriteLine("Dia chi : http://127.0.0.1:7860");
            Console.WriteLine("Dung    : nhan Ctrl+C trong cua so nay");
            Console.WriteLine("----------------------------------------");
            Console.WriteLine();

            int exitCode = 0;
            Process proc;
            try
            {
                proc = Process.Start(psi);
            }
            catch (Exception ex)
            {
                Console.WriteLine("[LOI] Khong khoi dong duoc Python: " + ex.Message);
                Pause();
                return 1;
            }

            Console.CancelKeyPress += delegate(object sender, ConsoleCancelEventArgs e)
            {
                e.Cancel = true;
                try
                {
                    if (!proc.HasExited)
                    {
                        proc.Kill();
                    }
                }
                catch { }
            };

            try
            {
                proc.WaitForExit();
                exitCode = proc.ExitCode;
            }
            catch (Exception ex)
            {
                Console.WriteLine("[LOI] " + ex.Message);
                exitCode = 1;
            }

            Console.WriteLine();
            if (exitCode != 0)
            {
                Console.WriteLine("[KET THUC] Ung dung dung voi ma loi " + exitCode + ". Xem log o tren.");
            }
            else
            {
                Console.WriteLine("[KET THUC] Ung dung da dong.");
            }

            Pause();
            return exitCode;
        }
    }
}
