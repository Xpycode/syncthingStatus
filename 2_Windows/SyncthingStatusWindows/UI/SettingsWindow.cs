using System;
using System.Drawing;
using System.Windows.Forms;

namespace SyncthingStatusWindows.UI
{
    public class SettingsWindow : Form
    {
        private readonly TextBox _baseUrlTextBox;
        private readonly TextBox _apiKeyTextBox;
        private readonly Button _saveButton;
        private readonly Button _cancelButton;

        public event EventHandler<(string baseUrl, string apiKey)>? ConfigurationSaved;

        public SettingsWindow()
        {
            // Form settings
            Text = "Settings - Syncthing Status";
            Size = new Size(500, 300);
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            MinimizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;

            // Main layout
            var mainLayout = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                Padding = new Padding(20),
                RowCount = 4,
                ColumnCount = 2
            };

            mainLayout.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
            mainLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            mainLayout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            mainLayout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            mainLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            mainLayout.RowStyles.Add(new RowStyle(SizeType.AutoSize));

            // Base URL
            var baseUrlLabel = new Label
            {
                Text = "Base URL:",
                AutoSize = true,
                Anchor = AnchorStyles.Left,
                Margin = new Padding(0, 5, 10, 5)
            };

            _baseUrlTextBox = new TextBox
            {
                Text = "http://127.0.0.1:8384",
                Dock = DockStyle.Fill,
                Margin = new Padding(0, 5, 0, 5)
            };

            // API Key
            var apiKeyLabel = new Label
            {
                Text = "API Key:",
                AutoSize = true,
                Anchor = AnchorStyles.Left,
                Margin = new Padding(0, 5, 10, 5)
            };

            _apiKeyTextBox = new TextBox
            {
                Dock = DockStyle.Fill,
                UseSystemPasswordChar = false,
                Margin = new Padding(0, 5, 0, 5)
            };

            // Info text
            var infoLabel = new Label
            {
                Text = "Find your API key in Syncthing's web interface:\n" +
                       "Actions → Settings → GUI → API Key\n\n" +
                       "Or it will be automatically discovered from:\n" +
                       "%LocalAppData%\\Syncthing\\config.xml\n" +
                       "%UserProfile%\\.config\\syncthing\\config.xml",
                AutoSize = true,
                ForeColor = Color.Gray,
                Margin = new Padding(0, 10, 0, 10)
            };

            // Buttons
            var buttonPanel = new FlowLayoutPanel
            {
                Dock = DockStyle.Fill,
                FlowDirection = FlowDirection.RightToLeft,
                AutoSize = true
            };

            _saveButton = new Button
            {
                Text = "Save",
                AutoSize = true,
                Padding = new Padding(15, 5, 15, 5)
            };
            _saveButton.Click += OnSaveClicked;

            _cancelButton = new Button
            {
                Text = "Cancel",
                AutoSize = true,
                Padding = new Padding(15, 5, 15, 5)
            };
            _cancelButton.Click += (s, e) => Close();

            buttonPanel.Controls.Add(_saveButton);
            buttonPanel.Controls.Add(_cancelButton);

            // Add controls to layout
            mainLayout.Controls.Add(baseUrlLabel, 0, 0);
            mainLayout.Controls.Add(_baseUrlTextBox, 1, 0);
            mainLayout.Controls.Add(apiKeyLabel, 0, 1);
            mainLayout.Controls.Add(_apiKeyTextBox, 1, 1);
            mainLayout.Controls.Add(infoLabel, 0, 2);
            mainLayout.SetColumnSpan(infoLabel, 2);
            mainLayout.Controls.Add(buttonPanel, 0, 3);
            mainLayout.SetColumnSpan(buttonPanel, 2);

            Controls.Add(mainLayout);
        }

        private void OnSaveClicked(object? sender, EventArgs e)
        {
            var baseUrl = _baseUrlTextBox.Text.Trim();
            var apiKey = _apiKeyTextBox.Text.Trim();

            if (string.IsNullOrWhiteSpace(baseUrl))
            {
                MessageBox.Show("Please enter a Base URL.", "Validation Error",
                    MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            if (string.IsNullOrWhiteSpace(apiKey))
            {
                MessageBox.Show("Please enter an API Key.", "Validation Error",
                    MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            // Validate URL format
            if (!Uri.TryCreate(baseUrl, UriKind.Absolute, out _))
            {
                MessageBox.Show("Invalid URL format.", "Validation Error",
                    MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            ConfigurationSaved?.Invoke(this, (baseUrl, apiKey));
            MessageBox.Show("Configuration saved successfully!", "Success",
                MessageBoxButtons.OK, MessageBoxIcon.Information);
            Close();
        }
    }
}
