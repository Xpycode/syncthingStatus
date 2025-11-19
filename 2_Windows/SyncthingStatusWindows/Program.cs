using System;
using System.Windows.Forms;

namespace SyncthingStatusWindows
{
    static class Program
    {
        [STAThread]
        static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.SetHighDpiMode(HighDpiMode.SystemAware);

            // Run the application with the system tray icon
            Application.Run(new ApplicationContext(new TrayApplicationContext()));
        }
    }
}
