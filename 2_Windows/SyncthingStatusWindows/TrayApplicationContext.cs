using System;
using System.Drawing;
using System.Windows.Forms;
using System.Xml;
using System.IO;
using SyncthingStatusWindows.Services;
using SyncthingStatusWindows.UI;

namespace SyncthingStatusWindows
{
    public class TrayApplicationContext : ApplicationContext
    {
        private readonly NotifyIcon _trayIcon;
        private readonly SyncthingClient _syncthingClient;
        private readonly System.Windows.Forms.Timer _refreshTimer;
        private MainWindow? _mainWindow;
        private SettingsWindow? _settingsWindow;
        private StatusPopup? _statusPopup;

        private const int RefreshIntervalSeconds = 10;

        public TrayApplicationContext()
        {
            _syncthingClient = new SyncthingClient();

            // Initialize tray icon
            _trayIcon = new NotifyIcon
            {
                Icon = CreateDisconnectedIcon(),
                Visible = true,
                Text = "Syncthing Status - Disconnected"
            };

            // Setup context menu
            var contextMenu = new ContextMenuStrip();
            contextMenu.Items.Add("Open Status Window", null, OnOpenStatusWindow);
            contextMenu.Items.Add("Settings", null, OnOpenSettings);
            contextMenu.Items.Add("-");
            contextMenu.Items.Add("Refresh", null, OnRefresh);
            contextMenu.Items.Add("-");
            contextMenu.Items.Add("Exit", null, OnExit);

            _trayIcon.ContextMenuStrip = contextMenu;
            _trayIcon.Click += OnTrayIconClick;
            _trayIcon.DoubleClick += OnTrayIconDoubleClick;

            // Load configuration and start monitoring
            LoadConfiguration();

            // Setup refresh timer
            _refreshTimer = new System.Windows.Forms.Timer
            {
                Interval = RefreshIntervalSeconds * 1000
            };
            _refreshTimer.Tick += async (s, e) => await RefreshDataAsync();
            _refreshTimer.Start();

            // Initial refresh
            _ = RefreshDataAsync();
        }

        private void LoadConfiguration()
        {
            try
            {
                // Try to auto-discover API key from Syncthing config
                var apiKey = TryAutoDiscoverApiKey();
                if (!string.IsNullOrWhiteSpace(apiKey))
                {
                    _syncthingClient.Configure("http://127.0.0.1:8384", apiKey);
                }
                else
                {
                    // Show settings window if no configuration found
                    _trayIcon.ShowBalloonTip(5000,
                        "Syncthing Status",
                        "Configuration needed. Right-click the tray icon and select Settings.",
                        ToolTipIcon.Info);
                }
            }
            catch
            {
                // Configuration loading errors are handled by showing settings
            }
        }

        private string? TryAutoDiscoverApiKey()
        {
            var possiblePaths = new[]
            {
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                    "Syncthing", "config.xml"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
                    ".config", "syncthing", "config.xml"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                    "Syncthing", "config.xml")
            };

            foreach (var path in possiblePaths)
            {
                if (File.Exists(path))
                {
                    try
                    {
                        var apiKey = ExtractApiKeyFromConfig(path);
                        if (!string.IsNullOrWhiteSpace(apiKey))
                        {
                            return apiKey;
                        }
                    }
                    catch
                    {
                        // Continue to next path
                    }
                }
            }

            return null;
        }

        private string? ExtractApiKeyFromConfig(string configPath)
        {
            try
            {
                var doc = new XmlDocument();
                doc.Load(configPath);

                var apiKeyNode = doc.SelectSingleNode("//configuration/gui/apikey");
                return apiKeyNode?.InnerText?.Trim();
            }
            catch
            {
                return null;
            }
        }

        private async System.Threading.Tasks.Task RefreshDataAsync()
        {
            var success = await _syncthingClient.RefreshAsync();

            // Update tray icon based on status
            UpdateTrayIcon();

            // Update popup if visible
            _statusPopup?.UpdateData(_syncthingClient);

            // Update main window if visible
            _mainWindow?.UpdateData(_syncthingClient);
        }

        private void UpdateTrayIcon()
        {
            if (!_syncthingClient.IsConnected)
            {
                _trayIcon.Icon = CreateDisconnectedIcon();
                _trayIcon.Text = "Syncthing Status - Disconnected";
                return;
            }

            var downloadSpeed = _syncthingClient.GetCurrentDownloadSpeed();
            var uploadSpeed = _syncthingClient.GetCurrentUploadSpeed();
            var isTransferring = downloadSpeed > 1024 || uploadSpeed > 1024; // > 1KB/s

            if (isTransferring)
            {
                _trayIcon.Icon = CreateSyncingIcon();
                _trayIcon.Text = $"Syncthing Status - Syncing\nDown: {FormatBytes(downloadSpeed)}/s\nUp: {FormatBytes(uploadSpeed)}/s";
            }
            else
            {
                // Check if all folders are synced
                var allSynced = true;
                foreach (var status in _syncthingClient.FolderStatuses.Values)
                {
                    if (status.State != "idle" || status.NeedFiles > 0 || status.NeedBytes > 0)
                    {
                        allSynced = false;
                        break;
                    }
                }

                if (allSynced)
                {
                    _trayIcon.Icon = CreateSyncedIcon();
                    _trayIcon.Text = $"Syncthing Status - Synced\n{_syncthingClient.Folders.Count} folders, {_syncthingClient.GetConnectedDevicesCount()} devices connected";
                }
                else
                {
                    _trayIcon.Icon = CreateSyncingIcon();
                    _trayIcon.Text = "Syncthing Status - Syncing";
                }
            }
        }

        private void OnTrayIconClick(object? sender, EventArgs e)
        {
            // Show popup on left-click
            if (e is MouseEventArgs mouseEvent && mouseEvent.Button == MouseButtons.Left)
            {
                ShowStatusPopup();
            }
        }

        private void OnTrayIconDoubleClick(object? sender, EventArgs e)
        {
            OnOpenStatusWindow(sender, e);
        }

        private void ShowStatusPopup()
        {
            if (_statusPopup == null || _statusPopup.IsDisposed)
            {
                _statusPopup = new StatusPopup(_syncthingClient);
                _statusPopup.OpenMainWindowRequested += (s, e) => OnOpenStatusWindow(s, e);
                _statusPopup.SettingsRequested += (s, e) => OnOpenSettings(s, e);
            }

            // Position popup near the tray icon
            var cursorPos = Cursor.Position;
            var screen = Screen.FromPoint(cursorPos);

            // Show popup near the bottom-right (where system tray usually is)
            var x = screen.WorkingArea.Right - _statusPopup.Width - 10;
            var y = screen.WorkingArea.Bottom - _statusPopup.Height - 10;

            _statusPopup.Location = new Point(x, y);
            _statusPopup.UpdateData(_syncthingClient);
            _statusPopup.Show();
            _statusPopup.BringToFront();
        }

        private void OnOpenStatusWindow(object? sender, EventArgs e)
        {
            if (_mainWindow == null || _mainWindow.IsDisposed)
            {
                _mainWindow = new MainWindow(_syncthingClient);
                _mainWindow.SettingsRequested += (s, e) => OnOpenSettings(s, e);
            }

            _mainWindow.Show();
            _mainWindow.BringToFront();
            _mainWindow.UpdateData(_syncthingClient);
        }

        private void OnOpenSettings(object? sender, EventArgs e)
        {
            if (_settingsWindow == null || _settingsWindow.IsDisposed)
            {
                _settingsWindow = new SettingsWindow();
                _settingsWindow.ConfigurationSaved += OnConfigurationSaved;
            }

            _settingsWindow.Show();
            _settingsWindow.BringToFront();
        }

        private async void OnConfigurationSaved(object? sender, (string baseUrl, string apiKey) config)
        {
            _syncthingClient.Configure(config.baseUrl, config.apiKey);
            await RefreshDataAsync();
        }

        private async void OnRefresh(object? sender, EventArgs e)
        {
            await RefreshDataAsync();
        }

        private void OnExit(object? sender, EventArgs e)
        {
            _trayIcon.Visible = false;
            _syncthingClient?.Dispose();
            _refreshTimer?.Stop();
            _refreshTimer?.Dispose();
            Application.Exit();
        }

        // Icon creation helpers
        private Icon CreateDisconnectedIcon()
        {
            return CreateIcon(Color.Gray);
        }

        private Icon CreateSyncedIcon()
        {
            return CreateIcon(Color.Green);
        }

        private Icon CreateSyncingIcon()
        {
            return CreateIcon(Color.Orange);
        }

        private Icon CreateIcon(Color color)
        {
            var bitmap = new Bitmap(16, 16);
            using (var g = Graphics.FromImage(bitmap))
            {
                g.Clear(Color.Transparent);
                using (var brush = new SolidBrush(color))
                {
                    g.FillEllipse(brush, 2, 2, 12, 12);
                }
                using (var pen = new Pen(Color.White, 2))
                {
                    g.DrawEllipse(pen, 4, 4, 8, 8);
                }
            }

            var icon = Icon.FromHandle(bitmap.GetHicon());
            return icon;
        }

        private string FormatBytes(double bytes)
        {
            string[] sizes = { "B", "KB", "MB", "GB", "TB" };
            int order = 0;
            double size = bytes;

            while (size >= 1024 && order < sizes.Length - 1)
            {
                order++;
                size /= 1024;
            }

            return $"{size:0.##} {sizes[order]}";
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                _trayIcon?.Dispose();
                _syncthingClient?.Dispose();
                _refreshTimer?.Dispose();
                _mainWindow?.Dispose();
                _settingsWindow?.Dispose();
                _statusPopup?.Dispose();
            }
            base.Dispose(disposing);
        }
    }
}
