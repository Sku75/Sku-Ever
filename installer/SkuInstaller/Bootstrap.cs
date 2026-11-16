using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

namespace SkuInstaller
{
    /// <summary>
    /// Sku-Ever 1.6: the downloaded installer is only a bootstrap.
    ///
    /// The user downloads Sku-Ever-Installer.exe and runs it. It places itself as
    /// the persistent copy in %LOCALAPPDATA%\SkuEverUpdater (unless a newer one is
    /// already there), starts that copy and exits. The persistent copy does the
    /// whole run, keeps itself current, and quietly moves the downloaded file to
    /// the Recycle Bin. From then on there is only the desktop shortcut.
    ///
    /// Why: a downloaded exe can never update itself, so it used to stay on its
    /// version forever and offered the same self-update on every start.
    ///
    /// Older downloaded copies (1.5 and earlier) do not hand off; they self-update
    /// the persistent copy and start it with --self-updated. The persistent copy
    /// then recognises its parent process as a downloaded Sku-Ever installer and
    /// removes it the same way.
    ///
    /// Safety: only the one file that started us, only when its version resource
    /// says it is a Sku-Ever installer, never the persistent copy itself, and to
    /// the Recycle Bin, so it can be restored.
    /// </summary>
    public static class Bootstrap
    {
        public const string RemoveSwitch = "--remove-bootstrap";
        public const string PidSwitch = "--bootstrap-pid";
        public const string NoHandOffSwitch = "--no-handoff";
        private const string InstallerFileName = "Sku-Ever-Installer.exe";
        private const string InstallerProduct = "Sku-Ever installer";

        /// <summary>Shown at the top of the opening screen after a removal was scheduled.</summary>
        public static string Notice { get; private set; }

        private static string RunningExe => Assembly.GetExecutingAssembly().Location;

        /// <summary>
        /// Called first thing in Main. Returns true when this downloaded copy has
        /// started the persistent copy and must exit now.
        /// </summary>
        public static bool HandOff(string[] args)
        {
            try
            {
                if (SelfUpdater.RunningFromPersistentCopy) return false;
                if (HasSwitch(args, NoHandOffSwitch)) return false;

                string persistent = Shortcut.InstallPersistentCopy();
                if (persistent == null || !File.Exists(persistent)) return false;

                var forwarded = new StringBuilder();
                for (int i = 0; i < (args ?? new string[0]).Length; i++)
                {
                    string a = args[i];
                    if (IsSwitch(a, RemoveSwitch) || IsSwitch(a, PidSwitch)) { i++; continue; }
                    forwarded.Append(Quote(a)).Append(' ');
                }
                forwarded.Append(RemoveSwitch).Append(' ').Append(Quote(RunningExe)).Append(' ')
                         .Append(PidSwitch).Append(' ').Append(Process.GetCurrentProcess().Id);

                Logger.Info($"Handing off to the persistent copy: {persistent} {forwarded}");
                Process.Start(new ProcessStartInfo
                {
                    FileName = persistent,
                    Arguments = forwarded.ToString(),
                    UseShellExecute = true,
                    WorkingDirectory = Path.GetDirectoryName(persistent) ?? "",
                });
                return true;
            }
            catch (Exception ex)
            {
                Logger.Warning($"Hand-off to the persistent copy failed ({ex.Message}); running from here.");
                return false;
            }
        }

        /// <summary>
        /// Called in the persistent copy: works out which downloaded installer
        /// started us and moves it to the Recycle Bin once it has exited.
        /// </summary>
        public static void StartRemoval(string[] args)
        {
            try
            {
                if (!SelfUpdater.RunningFromPersistentCopy) return;

                string path = SwitchValue(args, RemoveSwitch);
                int pid = 0;
                int.TryParse(SwitchValue(args, PidSwitch) ?? "", out pid);

                if (path == null && HasSwitch(args, SelfUpdater.UpdatedSwitch))
                {
                    // An older downloaded copy that self-updated us and started us.
                    pid = ParentProcessId();
                    if (pid > 0) path = WowLocator.ProcessImagePath(pid);
                }

                if (path == null || !IsDownloadedInstaller(path)) return;

                Notice = Loc.Get("bootstrap.removed");
                string target = path;
                int waitPid = pid;
                var t = new Thread(() => RemoveWhenExited(target, waitPid)) { IsBackground = false, Name = "BootstrapRemoval" };
                t.Start();
            }
            catch (Exception ex)
            {
                Logger.Warning($"Could not schedule removal of the downloaded installer: {ex.Message}");
            }
        }

        private static void RemoveWhenExited(string path, int pid)
        {
            try
            {
                if (pid > 0)
                {
                    try
                    {
                        using (var p = Process.GetProcessById(pid))
                            p.WaitForExit(30000);
                    }
                    catch (ArgumentException) { /* already gone */ }
                }

                for (int attempt = 0; attempt < 10 && File.Exists(path); attempt++)
                {
                    if (SendToRecycleBin(path) && !File.Exists(path))
                    {
                        Logger.Info($"Downloaded installer moved to the Recycle Bin: {path}");
                        return;
                    }
                    Thread.Sleep(500);
                }
                if (File.Exists(path)) Logger.Warning($"Could not move the downloaded installer to the Recycle Bin: {path}");
            }
            catch (Exception ex)
            {
                Logger.Warning($"Removing the downloaded installer failed: {ex.Message}");
            }
        }

        /// <summary>A Sku-Ever installer exe that is not our persistent copy.</summary>
        private static bool IsDownloadedInstaller(string path)
        {
            try
            {
                if (string.IsNullOrEmpty(path) || !File.Exists(path)) return false;
                if (!path.EndsWith(".exe", StringComparison.OrdinalIgnoreCase)) return false;

                string full = Path.GetFullPath(path);
                string persistentDir = Path.GetFullPath(Shortcut.PersistentDir).TrimEnd('\\') + "\\";
                if (full.StartsWith(persistentDir, StringComparison.OrdinalIgnoreCase)) return false;
                if (string.Equals(full, Path.GetFullPath(RunningExe), StringComparison.OrdinalIgnoreCase)) return false;

                var v = FileVersionInfo.GetVersionInfo(full);
                return string.Equals(v.OriginalFilename, InstallerFileName, StringComparison.OrdinalIgnoreCase)
                    && string.Equals(v.ProductName, InstallerProduct, StringComparison.OrdinalIgnoreCase);
            }
            catch { return false; }
        }

        // --- Recycle Bin (SHFileOperation, silent, undoable) ---

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct SHFILEOPSTRUCT
        {
            public IntPtr hwnd;
            public uint wFunc;
            public string pFrom;
            public string pTo;
            public ushort fFlags;
            public bool fAnyOperationsAborted;
            public IntPtr hNameMappings;
            public string lpszProgressTitle;
        }

        [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
        private static extern int SHFileOperation(ref SHFILEOPSTRUCT op);

        private const uint FO_DELETE = 0x0003;
        private const ushort FOF_SILENT = 0x0004, FOF_NOCONFIRMATION = 0x0010, FOF_ALLOWUNDO = 0x0040,
                             FOF_NOERRORUI = 0x0400;

        private static bool SendToRecycleBin(string path)
        {
            var op = new SHFILEOPSTRUCT
            {
                wFunc = FO_DELETE,
                pFrom = Path.GetFullPath(path) + "\0\0",
                fFlags = (ushort)(FOF_ALLOWUNDO | FOF_NOCONFIRMATION | FOF_SILENT | FOF_NOERRORUI),
            };
            return SHFileOperation(ref op) == 0 && !op.fAnyOperationsAborted;
        }

        // --- Parent process id (for older copies that do not pass --remove-bootstrap) ---

        [StructLayout(LayoutKind.Sequential)]
        private struct PROCESS_BASIC_INFORMATION
        {
            public IntPtr Reserved1;
            public IntPtr PebBaseAddress;
            public IntPtr Reserved2_0;
            public IntPtr Reserved2_1;
            public IntPtr UniqueProcessId;
            public IntPtr InheritedFromUniqueProcessId;
        }

        [DllImport("ntdll.dll")]
        private static extern int NtQueryInformationProcess(IntPtr process, int infoClass,
            ref PROCESS_BASIC_INFORMATION info, int size, out int returned);

        private static int ParentProcessId()
        {
            try
            {
                var info = new PROCESS_BASIC_INFORMATION();
                using (var self = Process.GetCurrentProcess())
                {
                    int status = NtQueryInformationProcess(self.Handle, 0, ref info,
                        Marshal.SizeOf(typeof(PROCESS_BASIC_INFORMATION)), out _);
                    return status == 0 ? info.InheritedFromUniqueProcessId.ToInt32() : 0;
                }
            }
            catch { return 0; }
        }

        // --- argument helpers ---

        private static string SwitchValue(string[] args, string name)
        {
            if (args == null) return null;
            for (int i = 0; i < args.Length - 1; i++)
                if (IsSwitch(args[i], name)) return args[i + 1].Trim('"');
            return null;
        }

        private static bool HasSwitch(string[] args, string name)
        {
            if (args == null) return false;
            foreach (var a in args) if (IsSwitch(a, name)) return true;
            return false;
        }

        private static bool IsSwitch(string arg, string name) =>
            string.Equals(arg, name, StringComparison.OrdinalIgnoreCase);

        private static string Quote(string arg) =>
            arg != null && arg.IndexOf(' ') >= 0 && !arg.StartsWith("\"") ? "\"" + arg + "\"" : arg;
    }
}
