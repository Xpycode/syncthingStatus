using System;
using System.Drawing;
using System.Windows.Forms;
using SyncthingStatusWindows.Services;

namespace SyncthingStatusWindows.UI
{
    public class StatusPopup : Form
    {
        private readonly Label _statusLabel;
        private readonly Label _devicesLabel;
        private readonly Label _foldersLabel;
        private readonly Label _transferLabel;
        private readonly Button _openWindowButton;
        private readonly Button _settingsButton;

        public event EventHandler? OpenMainWindowRequested;
        public event EventHandler? SettingsRequested;

        public StatusPopup(SyncthingClient client)
        {
            // Form settings
            Text = "Syncthing Status";
            Size = new Size(350, 250);
            FormBorderStyle = FormBorderStyle.FixedSingle;
            MaximizeBox = false;
            MinimizeBox = false;
            ShowInTaskbar = false;
            StartPosition = FormStartPosition.Manual;
            TopMost = true;

            // Deactivate event to hide when clicking outside
            Deactivate += (s, e) => Hide();

            // Create UI controls
            var mainPanel = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                Padding = new Padding(15),
                RowCount = 6,
                ColumnCount = 1
            };

            // Title
            var titleLabel = new Label
            {
                Text = "Syncthing Status",
                Font = new Font(Font.FontFamily, 12, FontStyle.Bold),
                AutoSize = true
            };

            _statusLabel = new Label
            {
                Text = "Checking...",
                AutoSize = true,
                ForeColor = Color.Gray
            };

            _devicesLabel = new Label
            {
                Text = "Devices: -",
                AutoSize = true
            };

            _foldersLabel = new Label
            {
                Text = "Folders: -",
                AutoSize = true
            };

            _transferLabel = new Label
            {
                Text = "Transfer: -",
                AutoSize = true
            };

            var buttonPanel = new FlowLayoutPanel
            {
                Dock = DockStyle.Fill,
                FlowDirection = FlowDirection.LeftToRight,
                WrapContents = false,
                AutoSize = true
            };

            _openWindowButton = new Button
            {
                Text = "Open Window",
                AutoSize = true,
                Padding = new Padding(10, 5, 10, 5)
            };
            _openWindowButton.Click += (s, e) =>
            {
                OpenMainWindowRequested?.Invoke(this, EventArgs.Empty);
                Hide();
            };

            _settingsButton = new Button
            {
                Text = "Settings",
                AutoSize = true,
                Padding = new Padding(10, 5, 10, 5)
            };
            _settingsButton.Click += (s, e) =>
            {
                SettingsRequested?.Invoke(this, EventArgs.Empty);
                Hide();
            };

            buttonPanel.Controls.Add(_openWindowButton);
            buttonPanel.Controls.Add(_settingsButton);

            // Add controls to main panel
            mainPanel.Controls.Add(titleLabel, 0, 0);
            mainPanel.Controls.Add(_statusLabel, 0, 1);
            mainPanel.Controls.Add(_devicesLabel, 0, 2);
            mainPanel.Controls.Add(_foldersLabel, 0, 3);
            mainPanel.Controls.Add(_transferLabel, 0, 4);
            mainPanel.Controls.Add(buttonPanel, 0, 5);

            mainPanel.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            mainPanel.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            mainPanel.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            mainPanel.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            mainPanel.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            mainPanel.RowStyles.Add(new RowStyle(SizeType.AutoSize));

            Controls.Add(mainPanel);
        }

        public void UpdateData(SyncthingClient client)
        {
            if (InvokeRequired)
            {
                Invoke(new Action(() => UpdateData(client)));
                return;
            }

            if (!client.IsConnected)
            {
                _statusLabel.Text = "Disconnected";
                _statusLabel.ForeColor = Color.Red;
                _devicesLabel.Text = "Devices: -";
                _foldersLabel.Text = "Folders: -";
                _transferLabel.Text = "Transfer: -";
                return;
            }

            // Check sync status
            var allSynced = true;
            var syncingCount = 0;
            foreach (var status in client.FolderStatuses.Values)
            {
                if (status.State == "syncing" || status.NeedFiles > 0 || status.NeedBytes > 0)
                {
                    allSynced = false;
                    if (status.State == "syncing")
                    {
                        syncingCount++;
                    }
                }
            }

            if (allSynced)
            {
                _statusLabel.Text = "✓ All Synced";
                _statusLabel.ForeColor = Color.Green;
            }
            else if (syncingCount > 0)
            {
                _statusLabel.Text = $"⟳ Syncing ({syncingCount} folder{(syncingCount != 1 ? "s" : "")})";
                _statusLabel.ForeColor = Color.Orange;
            }
            else
            {
                _statusLabel.Text = "Idle";
                _statusLabel.ForeColor = Color.Gray;
            }

            var connectedDevices = client.GetConnectedDevicesCount();
            _devicesLabel.Text = $"Devices: {connectedDevices}/{client.Devices.Count} connected";

            _foldersLabel.Text = $"Folders: {client.Folders.Count}";

            var downloadSpeed = client.GetCurrentDownloadSpeed();
            var uploadSpeed = client.GetCurrentUploadSpeed();

            if (downloadSpeed > 0 || uploadSpeed > 0)
            {
                _transferLabel.Text = $"Transfer: ↓ {FormatBytes(downloadSpeed)}/s  ↑ {FormatBytes(uploadSpeed)}/s";
            }
            else
            {
                _transferLabel.Text = "Transfer: Idle";
            }
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
    }
}
