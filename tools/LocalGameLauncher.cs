// 현재 소스를 설치된 Godot으로 여는 단일 로컬 실행기.
using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;
internal static class LocalGameLauncher
{
    [STAThread]
    private static int Main(string[] args)
    {
        try
        {
            bool smoke = args.Length == 1 && args[0] == "--smoke";
            string root = AppDomain.CurrentDomain.BaseDirectory;
            string project = Path.Combine(root, "godot");
            string engine = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"Microsoft\WinGet\Links\godot.exe");
            if (!File.Exists(engine) || !File.Exists(Path.Combine(project, "project.godot")))
                throw new FileNotFoundException("설치된 Godot 또는 프로젝트를 찾을 수 없습니다. 실행 파일을 게임 폴더에 두세요.");
            string logs = Path.Combine(root, "docs/qa/screenshots/launcher");
            Directory.CreateDirectory(logs);
            string log = Path.Combine(logs, "game-" + DateTime.Now.ToString("yyyyMMdd-HHmmss-fff") + ".log");
            string options = "--path \"" + project + "\" --log-file \"" + log + "\"";
            if (smoke) options += " --quit-after 120";
            options += " res://scenes/world/game_bootstrap.tscn";
            if (smoke) options += " -- --product-smoke";
            var start = new ProcessStartInfo(engine, options);
            start.WorkingDirectory = root;
            start.UseShellExecute = false;
            if (smoke) start.WindowStyle = ProcessWindowStyle.Hidden;
            using (var process = Process.Start(start))
            {
                if (!smoke) return 0;
                if (!process.WaitForExit(60000)) { process.Kill(); return 2; }
                string output = File.Exists(log) ? File.ReadAllText(log) : "";
                if (output.Contains("SCRIPT ERROR:") || output.Contains("ERROR:")) return 3;
                if (!output.Contains("PRODUCT_READY")) return 4;
                return process.ExitCode;
            }
        }
        catch (Exception error)
        {
            if (args.Length == 0) MessageBox.Show(error.Message, "게임 실행 오류");
            return 1;
        }
    }
}
