// 설치된 Godot으로 현재 작업 폴더를 여는 로컬 테스트 실행기. 배포용 게임 바이너리가 아니다.
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
            string engine = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                @"Microsoft\WinGet\Links\godot.exe");
            if (!File.Exists(engine) || !File.Exists(Path.Combine(project, "project.godot")))
                throw new FileNotFoundException("설치된 Godot 또는 godot/project.godot을 찾을 수 없습니다. 실행 파일을 게임 폴더 안에 두세요.");
#if CLOSURE
            string mode = "m7-closure";
            string entry = " --script scripts/tools/m7_closure_play.gd -- --quick";
#elif M7
            string mode = "m7";
            string entry = " --script scripts/tools/m7_candidate_play.gd -- --quick";
#elif SHOP
            string mode = "m6-shop";
            string entry = " --script ../docs/qa/tools/m6_shop_play.gd";
#elif M6
            string mode = "m6";
            string entry = " --script ../docs/qa/tools/m6_candidate_probe.gd -- play";
#else
            string mode = "game";
            string entry = " res://scenes/world/eastern_frontier_starting_area.tscn";
#endif
            string logs = Path.Combine(root, "docs/qa/screenshots/launcher");
            Directory.CreateDirectory(logs);
            string log = Path.Combine(logs, mode + "-" + DateTime.Now.ToString("yyyyMMdd-HHmmss-fff") + ".log");
            string options = "--path \"" + project + "\" --log-file \"" + log + "\"";
            if (smoke) options += " --quit-after 120";
            var start = new ProcessStartInfo(engine, options + entry);
            start.WorkingDirectory = root;
            start.UseShellExecute = false;
            if (smoke) start.WindowStyle = ProcessWindowStyle.Hidden;
            using (var process = Process.Start(start))
            {
                if (!smoke) return 0;
                if (!process.WaitForExit(60000)) { process.Kill(); return 2; }
                string output = File.Exists(log) ? File.ReadAllText(log) : "";
                if (output.Length == 0 || output.Contains("SCRIPT ERROR:") || output.Contains("ERROR:")) return 3;
#if CLOSURE
                if (!output.Contains("M7_CLOSURE_PLAY_READY")) return 4;
#elif M7
                if (!output.Contains("M7_PLAY_READY")) return 4;
#elif SHOP
                if (!output.Contains("M6_SHOP_READY")) return 4;
#elif M6
                if (!output.Contains("M6_CANDIDATE_READY")) return 4;
#endif
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
