// Upfly Code - identidade na barra de tarefas do Windows.
//
// Compilado na instalação (Add-Type) como bin\upfly-taskbar.exe.
//
// Modo padrão: enquanto houver janelas do UpflyCode.exe abertas, aplica em
// cada uma:
//   - AppUserModelID "Upfly.UpflyCode" + ícone/nome/comando de "relançar"
//     (é isso que a barra de tarefas usa para o ícone do botão e ao fixar);
//   - WM_SETICON com o ícone da Upfly (barra de título, Alt+Tab).
//   Uso: upfly-taskbar.exe <icone.ico> <comando para reabrir> [appid]
//
// Modo atalho: grava o AppUserModelID num atalho .lnk, para o atalho do
// Menu Iniciar e o botão da janela serem o mesmo item na barra.
//   Uso: upfly-taskbar.exe --set-lnk-appid <atalho.lnk> <appid>
//
// Escrito em C# 5 (compatível com o compilador do Windows PowerShell 5.1).
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
using System.Threading;

namespace Upfly
{
    [ComImport, Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IPropertyStore
    {
        [PreserveSig] int GetCount(out uint cProps);
        [PreserveSig] int GetAt(uint iProp, out PropertyKey pkey);
        [PreserveSig] int GetValue(ref PropertyKey key, out PropVariant pv);
        [PreserveSig] int SetValue(ref PropertyKey key, ref PropVariant pv);
        [PreserveSig] int Commit();
    }

    [StructLayout(LayoutKind.Sequential, Pack = 4)]
    struct PropertyKey
    {
        public Guid fmtid;
        public uint pid;
        public PropertyKey(Guid g, uint p) { fmtid = g; pid = p; }
    }

    [StructLayout(LayoutKind.Explicit, Size = 24)]
    struct PropVariant
    {
        [FieldOffset(0)] public ushort vt;
        [FieldOffset(8)] public IntPtr p;

        public static PropVariant FromString(string s)
        {
            PropVariant v = new PropVariant();
            v.vt = 31; // VT_LPWSTR
            v.p = Marshal.StringToCoTaskMemUni(s);
            return v;
        }
    }

    [ComImport, Guid("000214F9-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IShellLinkW
    {
        void GetPath(IntPtr pszFile, int cch, IntPtr pfd, uint fFlags);
        void GetIDList(out IntPtr ppidl);
        void SetIDList(IntPtr pidl);
        void GetDescription(IntPtr pszName, int cch);
        void SetDescription([MarshalAs(UnmanagedType.LPWStr)] string pszName);
        void GetWorkingDirectory(IntPtr pszDir, int cch);
        void SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string pszDir);
        void GetArguments(IntPtr pszArgs, int cch);
        void SetArguments([MarshalAs(UnmanagedType.LPWStr)] string pszArgs);
        void GetHotkey(out short pwHotkey);
        void SetHotkey(short wHotkey);
        void GetShowCmd(out int piShowCmd);
        void SetShowCmd(int iShowCmd);
        void GetIconLocation(IntPtr pszIconPath, int cch, out int piIcon);
        void SetIconLocation([MarshalAs(UnmanagedType.LPWStr)] string pszIconPath, int iIcon);
        void SetRelativePath([MarshalAs(UnmanagedType.LPWStr)] string pszPathRel, uint dwReserved);
        void Resolve(IntPtr hwnd, uint fFlags);
        void SetPath([MarshalAs(UnmanagedType.LPWStr)] string pszFile);
    }

    [ComImport, Guid("00021401-0000-0000-C000-000000000046")]
    class ShellLink { }

    static class Native
    {
        public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

        [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lParam);
        [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
        [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
        [DllImport("user32.dll")] public static extern IntPtr GetWindow(IntPtr hWnd, uint cmd);
        [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr hWnd, uint msg, IntPtr w, IntPtr l);
        [DllImport("user32.dll")] public static extern int GetSystemMetrics(int i);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        public static extern IntPtr LoadImage(IntPtr hinst, string name, uint type, int cx, int cy, uint flags);
        [DllImport("user32.dll", EntryPoint = "SetClassLongPtrW")]
        public static extern IntPtr SetClassLongPtr64(IntPtr hWnd, int index, IntPtr value);
        [DllImport("user32.dll", EntryPoint = "SetClassLongW")]
        public static extern int SetClassLong32(IntPtr hWnd, int index, int value);
        [DllImport("shell32.dll")]
        public static extern int SHGetPropertyStoreForWindow(IntPtr hwnd, ref Guid iid, [MarshalAs(UnmanagedType.Interface)] out IPropertyStore store);
        [DllImport("ole32.dll")] public static extern int PropVariantClear(ref PropVariant pv);
    }

    static class Program
    {
        static readonly Guid AppModelFmt = new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3");
        static PropertyKey PkeyRelaunchCommand = new PropertyKey(AppModelFmt, 2);
        static PropertyKey PkeyRelaunchIcon = new PropertyKey(AppModelFmt, 3);
        static PropertyKey PkeyRelaunchName = new PropertyKey(AppModelFmt, 4);
        static PropertyKey PkeyAppId = new PropertyKey(AppModelFmt, 5);
        static Guid IidPropertyStore = new Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99");

        const uint WM_SETICON = 0x0080, WM_GETICON = 0x007F;
        const uint IMAGE_ICON = 1, LR_LOADFROMFILE = 0x10;

        static void SetString(IPropertyStore store, PropertyKey key, string value)
        {
            PropVariant v = PropVariant.FromString(value);
            store.SetValue(ref key, ref v);
            Native.PropVariantClear(ref v);
        }

        static void SetClassIcon(IntPtr hwnd, int index, IntPtr icon)
        {
            if (IntPtr.Size == 8) Native.SetClassLongPtr64(hwnd, index, icon);
            else Native.SetClassLong32(hwnd, index, icon.ToInt32());
        }

        static int Main(string[] args)
        {
            try
            {
                if (args.Length >= 3 && args[0] == "--set-lnk-appid")
                    return SetShortcutAppId(args[1], args[2]);
                if (args.Length < 2) return 2;
                return Watch(args[0], args[1], args.Length > 2 ? args[2] : "Upfly.UpflyCode");
            }
            catch (Exception)
            {
                return 1;
            }
        }

        static int SetShortcutAppId(string lnk, string appId)
        {
            IShellLinkW link = (IShellLinkW)new ShellLink();
            IPersistFile file = (IPersistFile)link;
            file.Load(lnk, 2 /* STGM_READWRITE */);
            IPropertyStore store = (IPropertyStore)link;
            SetString(store, PkeyAppId, appId);
            store.Commit();
            file.Save(lnk, true);
            return 0;
        }

        static int Watch(string iconPath, string relaunch, string appId)
        {
            bool created;
            using (Mutex m = new Mutex(true, "Local\\UpflyCodeTaskbar", out created))
            {
                if (!created) return 0;

                int small = Native.GetSystemMetrics(49); // SM_CXSMICON
                int big = Native.GetSystemMetrics(11);   // SM_CXICON
                IntPtr hSmall = Native.LoadImage(IntPtr.Zero, iconPath, IMAGE_ICON, small, small, LR_LOADFROMFILE);
                IntPtr hBig = Native.LoadImage(IntPtr.Zero, iconPath, IMAGE_ICON, big, big, LR_LOADFROMFILE);
                Dictionary<IntPtr, bool> tagged = new Dictionary<IntPtr, bool>();
                int idle = 0;

                while (idle < 4)
                {
                    Dictionary<uint, bool> pids = new Dictionary<uint, bool>();
                    foreach (Process p in Process.GetProcessesByName("UpflyCode")) pids[(uint)p.Id] = true;
                    if (pids.Count == 0) { idle++; Thread.Sleep(1500); continue; }
                    idle = 0;

                    Native.EnumWindows(delegate (IntPtr hwnd, IntPtr l)
                    {
                        uint pid;
                        Native.GetWindowThreadProcessId(hwnd, out pid);
                        if (!pids.ContainsKey(pid) || !Native.IsWindowVisible(hwnd)) return true;
                        if (Native.GetWindow(hwnd, 4 /* GW_OWNER */) != IntPtr.Zero) return true;

                        if (!tagged.ContainsKey(hwnd))
                        {
                            IPropertyStore store;
                            Guid iid = IidPropertyStore;
                            if (Native.SHGetPropertyStoreForWindow(hwnd, ref iid, out store) == 0 && store != null)
                            {
                                SetString(store, PkeyRelaunchCommand, relaunch);
                                SetString(store, PkeyRelaunchIcon, iconPath + ",0");
                                SetString(store, PkeyRelaunchName, "Upfly Code");
                                SetString(store, PkeyAppId, appId);
                                Marshal.ReleaseComObject(store);
                            }
                            tagged[hwnd] = true;
                        }
                        // reaplica o ícone se o motor trocar
                        if (hBig != IntPtr.Zero &&
                            Native.SendMessage(hwnd, WM_GETICON, (IntPtr)1, IntPtr.Zero) != hBig)
                        {
                            Native.SendMessage(hwnd, WM_SETICON, (IntPtr)0, hSmall);
                            Native.SendMessage(hwnd, WM_SETICON, (IntPtr)1, hBig);
                            SetClassIcon(hwnd, -34 /* GCLP_HICONSM */, hSmall);
                            SetClassIcon(hwnd, -14 /* GCLP_HICON */, hBig);
                        }
                        return true;
                    }, IntPtr.Zero);

                    Thread.Sleep(1000);
                }
            }
            return 0;
        }
    }
}
