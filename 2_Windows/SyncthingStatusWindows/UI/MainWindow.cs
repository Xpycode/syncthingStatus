using System;
using System.Drawing;
using System.Linq;
using System.Windows.Forms;
using SyncthingStatusWindows.Services;

namespace SyncthingStatusWindows.UI
{
    public class MainWindow : Form
    {
        private readonly SyncthingClient _client;
        private readonly Label _connectionStatusLabel;
        private readonly Label _localDeviceLabel;
        private readonly Label _versionLabel;
        private readonly Label _uptimeLabel;
        private readonly Label _summaryLabel;
        private readonly ListView _devicesListView;
        private readonly ListView _foldersListView;

        public event EventHandler? SettingsRequested;

        public MainWindow(SyncthingClient client)
        {
            _client = client;

            // Form settings
            Text = "Syncthing Status";
            Size = new Size(900, 700);
            MinimumSize = new Size(600, 400);
            StartPosition = FormStartPosition.CenterScreen;

            // Create menu
            var menuStrip = new MenuStrip();
            var fileMenu = new ToolStripMenuItem("File");
            fileMenu.DropDownItems.Add("Settings", null, (s, e) => SettingsRequested?.Invoke(this, EventArgs.Empty));
            fileMenu.DropDownItems.Add(new ToolStripSeparator());
            fileMenu.DropDownItems.Add("Exit", null, (s, e) => Close());

            var viewMenu = new ToolStripMenuItem("View");
            viewMenu.DropDownItems.Add("Refresh", null, async (s, e) => await _client.RefreshAsync());

            menuStrip.Items.Add(fileMenu);
            menuStrip.Items.Add(viewMenu);

            // Main layout
            var mainLayout = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                Padding = new Padding(10),
                RowCount = 3,
                ColumnCount = 1
            };

            // System info panel
            var systemPanel = CreateSystemPanel();
            _connectionStatusLabel = systemPanel.Controls.Find("connectionStatus", true).FirstOrDefault() as Label ?? new Label();
            _localDeviceLabel = systemPanel.Controls.Find("localDevice", true).FirstOrDefault() as Label ?? new Label();
            _versionLabel = systemPanel.Controls.Find("version", true).FirstOrDefault() as Label ?? new Label();
            _uptimeLabel = systemPanel.Controls.Find("uptime", true).FirstOrDefault() as Label ?? new Label();
            _summaryLabel = systemPanel.Controls.Find("summary", true).FirstOrDefault() as Label ?? new Label();

            // Devices section
            var devicesGroup = new GroupBox
            {
                Text = "Devices",
                Dock = DockStyle.Fill,
                Padding = new Padding(10)
            };

            _devicesListView = new ListView
            {
                Dock = DockStyle.Fill,
                View = View.Details,
                FullRowSelect = true,
                GridLines = true
            };

            _devicesListView.Columns.Add("Device Name", 200);
            _devicesListView.Columns.Add("Status", 100);
            _devicesListView.Columns.Add("Completion", 100);
            _devicesListView.Columns.Add("Address", 200);
            _devicesListView.Columns.Add("Download", 100);
            _devicesListView.Columns.Add("Upload", 100);

            devicesGroup.Controls.Add(_devicesListView);

            // Folders section
            var foldersGroup = new GroupBox
            {
                Text = "Folders",
                Dock = DockStyle.Fill,
                Padding = new Padding(10)
            };

            _foldersListView = new ListView
            {
                Dock = DockStyle.Fill,
                View = View.Details,
                FullRowSelect = true,
                GridLines = true
            };

            _foldersListView.Columns.Add("Folder Name", 200);
            _foldersListView.Columns.Add("Status", 100);
            _foldersListView.Columns.Add("Local Files", 100);
            _foldersListView.Columns.Add("Local Size", 120);
            _foldersListView.Columns.Add("Need Files", 100);
            _foldersListView.Columns.Add("Need Size", 120);

            foldersGroup.Controls.Add(_foldersListView);

            // Add panels to main layout
            mainLayout.Controls.Add(systemPanel, 0, 0);
            mainLayout.Controls.Add(devicesGroup, 0, 1);
            mainLayout.Controls.Add(foldersGroup, 0, 2);

            mainLayout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            mainLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 50));
            mainLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 50));

            Controls.Add(mainLayout);
            Controls.Add(menuStrip);
            MainMenuStrip = menuStrip;
        }

        private Panel CreateSystemPanel()
        {
            var panel = new GroupBox
            {
                Text = "System Information",
                Dock = DockStyle.Fill,
                Padding = new Padding(10),
                AutoSize = true
            };

            var layout = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                AutoSize = true,
                ColumnCount = 2,
                RowCount = 5
            };

            layout.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
            layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));

            // Connection Status
            layout.Controls.Add(new Label { Text = "Status:", AutoSize = true, Font = new Font(Font, FontStyle.Bold) }, 0, 0);
            var connectionStatus = new Label { Name = "connectionStatus", Text = "Checking...", AutoSize = true };
            layout.Controls.Add(connectionStatus, 1, 0);

            // Local Device
            layout.Controls.Add(new Label { Text = "Device:", AutoSize = true, Font = new Font(Font, FontStyle.Bold) }, 0, 1);
            var localDevice = new Label { Name = "localDevice", Text = "-", AutoSize = true };
            layout.Controls.Add(localDevice, 1, 1);

            // Version
            layout.Controls.Add(new Label { Text = "Version:", AutoSize = true, Font = new Font(Font, FontStyle.Bold) }, 0, 2);
            var version = new Label { Name = "version", Text = "-", AutoSize = true };
            layout.Controls.Add(version, 1, 2);

            // Uptime
            layout.Controls.Add(new Label { Text = "Uptime:", AutoSize = true, Font = new Font(Font, FontStyle.Bold) }, 0, 3);
            var uptime = new Label { Name = "uptime", Text = "-", AutoSize = true };
            layout.Controls.Add(uptime, 1, 3);

            // Summary
            layout.Controls.Add(new Label { Text = "Summary:", AutoSize = true, Font = new Font(Font, FontStyle.Bold) }, 0, 4);
            var summary = new Label { Name = "summary", Text = "-", AutoSize = true };
            layout.Controls.Add(summary, 1, 4);

            panel.Controls.Add(layout);
            return panel;
        }

        public void UpdateData(SyncthingClient client)
        {
            if (InvokeRequired)
            {
                Invoke(new Action(() => UpdateData(client)));
                return;
            }

            // Update system info
            if (!client.IsConnected)
            {
                _connectionStatusLabel.Text = "Disconnected";
                _connectionStatusLabel.ForeColor = Color.Red;
                _localDeviceLabel.Text = "-";
                _versionLabel.Text = "-";
                _uptimeLabel.Text = "-";
                _summaryLabel.Text = "-";
                _devicesListView.Items.Clear();
                _foldersListView.Items.Clear();
                return;
            }

            _connectionStatusLabel.Text = "Connected";
            _connectionStatusLabel.ForeColor = Color.Green;
            _localDeviceLabel.Text = client.LocalDeviceName;
            _versionLabel.Text = client.SyncthingVersion ?? "-";

            if (client.SystemStatus != null)
            {
                var uptime = TimeSpan.FromSeconds(client.SystemStatus.Uptime);
                _uptimeLabel.Text = $"{uptime.Days}d {uptime.Hours}h {uptime.Minutes}m";
            }

            var connectedDevices = client.GetConnectedDevicesCount();
            var totalData = client.GetTotalSyncedData();
            var downloadSpeed = client.GetCurrentDownloadSpeed();
            var uploadSpeed = client.GetCurrentUploadSpeed();

            _summaryLabel.Text = $"{client.Folders.Count} folders, {connectedDevices}/{client.Devices.Count} devices, " +
                                 $"{FormatBytes(totalData)} synced, " +
                                 $"↓ {FormatBytes(downloadSpeed)}/s, ↑ {FormatBytes(uploadSpeed)}/s";

            // Update devices list
            _devicesListView.Items.Clear();
            foreach (var device in client.Devices)
            {
                var connection = client.Connections.GetValueOrDefault(device.DeviceID);
                var completion = client.DeviceCompletions.GetValueOrDefault(device.DeviceID);
                var rates = client.TransferRates.GetValueOrDefault(device.DeviceID);

                var item = new ListViewItem(device.Name);
                item.SubItems.Add(connection?.Connected == true ? "Connected" : "Disconnected");
                item.SubItems.Add(completion != null ? $"{completion.Completion:F1}%" : "-");
                item.SubItems.Add(connection?.Address ?? "-");
                item.SubItems.Add(rates != null && rates.DownloadRate > 0 ? $"{FormatBytes(rates.DownloadRate)}/s" : "-");
                item.SubItems.Add(rates != null && rates.UploadRate > 0 ? $"{FormatBytes(rates.UploadRate)}/s" : "-");

                if (connection?.Connected == true)
                {
                    item.ForeColor = Color.Green;
                }
                else
                {
                    item.ForeColor = Color.Gray;
                }

                _devicesListView.Items.Add(item);
            }

            // Update folders list
            _foldersListView.Items.Clear();
            foreach (var folder in client.Folders)
            {
                var status = client.FolderStatuses.GetValueOrDefault(folder.ID);

                var item = new ListViewItem(folder.Label.Length > 0 ? folder.Label : folder.ID);
                item.SubItems.Add(status?.State ?? "-");
                item.SubItems.Add(status?.LocalFiles.ToString() ?? "-");
                item.SubItems.Add(status != null ? FormatBytes(status.LocalBytes) : "-");
                item.SubItems.Add(status?.NeedFiles.ToString() ?? "-");
                item.SubItems.Add(status != null ? FormatBytes(status.NeedBytes) : "-");

                if (status != null)
                {
                    if (status.State == "syncing")
                    {
                        item.ForeColor = Color.Orange;
                    }
                    else if (status.State == "idle" && status.NeedFiles == 0)
                    {
                        item.ForeColor = Color.Green;
                    }
                    else
                    {
                        item.ForeColor = Color.Gray;
                    }
                }

                _foldersListView.Items.Add(item);
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
