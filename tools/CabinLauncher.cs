using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Windows.Forms;

internal static class CabinLauncher {
    // ProcessStartInfo on the Windows .NET Framework takes a single argument string.
    private static string Quote(string value) {
        var result = new StringBuilder("\"");
        int slashes = 0;
        foreach (char c in value) {
            if (c == '\\') { slashes++; continue; }
            if (c == '"') { result.Append('\\', 2 * slashes + 1); }
            else { result.Append('\\', slashes); }
            result.Append(c);
            slashes = 0;
        }
        return result.Append('\\', 2 * slashes).Append('"').ToString();
    }
    [STAThread]
    private static int Main(string[] args) {
        string root = AppDomain.CurrentDomain.BaseDirectory;
        try {
            if (args.Length == 0) {
                string ps = Path.Combine(Environment.SystemDirectory, @"WindowsPowerShell\v1.0\powershell.exe");
                var prompt = new ProcessStartInfo(ps, "-NoProfile -STA -ExecutionPolicy Bypass -File " + Quote(Path.Combine(root, @"tools\install.ps1")));
                prompt.WorkingDirectory = root;
                prompt.UseShellExecute = false;
                prompt.CreateNoWindow = true;
                using (var wizard = Process.Start(prompt)) {
                    wizard.WaitForExit();
                    if (wizard.ExitCode != 0) return wizard.ExitCode;
                }
            }
            var arguments = new StringBuilder();
            foreach (string arg in args) arguments.Append(' ').Append(Quote(arg));
            var start = new ProcessStartInfo(Path.Combine(root, "CabinWorld.engine.exe"),arguments.ToString());
            start.WorkingDirectory = root;
            start.UseShellExecute = false;
            using (var game = Process.Start(start)) {
                game.WaitForExit();
                return game.ExitCode;
            }
        } catch (Exception error) {
            MessageBox.Show(error.Message, "小屋世界");
            return 1;
        }
    }
}

