# Syncthing Status for Windows

A lightweight Windows taskbar application for monitoring [Syncthing](https://syncthing.net) status in real-time.

![Windows](https://img.shields.io/badge/Windows-10%2F11-blue)
![.NET](https://img.shields.io/badge/.NET-8.0-purple)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **System Tray Integration**: Unobtrusive status indicator that lives in your Windows taskbar
- **Real-Time Monitoring**: Automatic updates every 10 seconds
- **Visual Status Indicators**:
  - 🟢 **Green**: All folders synced
  - 🟠 **Orange**: Currently syncing
  - ⚫ **Gray**: Disconnected from Syncthing
- **Quick Status Popup**: Click the tray icon for a quick overview
- **Detailed Window**: Double-click or use the context menu for comprehensive information
- **Device Monitoring**: Track connection status, sync progress, and transfer rates for all remote devices
- **Folder Status**: View sync state, file counts, and data sizes for each shared folder
- **Automatic Configuration**: Discovers API key from local Syncthing config.xml
- **Manual Configuration**: Connect to remote Syncthing instances with custom URL and API key

## Screenshots

### System Tray Icon
The app lives in your Windows taskbar notification area, showing the current sync status at a glance.

### Status Popup
Quick access to essential information with a single click on the tray icon:
- Current sync status
- Connected devices count
- Number of folders
- Current transfer speeds
- Quick access to detailed view and settings

### Main Window
Comprehensive overview with:
- System information (device name, version, uptime)
- Detailed device list with connection status and transfer rates
- Folder list with sync progress and file counts
- Real-time statistics

### Settings
Configure connection to your Syncthing instance:
- Base URL (default: http://127.0.0.1:8384)
- API Key (auto-discovered or manually entered)

## Requirements

- Windows 10 or Windows 11
- [.NET 8.0 Runtime](https://dotnet.microsoft.com/download/dotnet/8.0) (Desktop Runtime)
- [Syncthing](https://syncthing.net) installed and running

## Installation

### Option 1: Download Pre-built Executable (Coming Soon)
1. Download the latest release from the Releases page
2. Extract the ZIP file to a location of your choice
3. Run `SyncthingStatus.exe`
4. The app will appear in your system tray

### Option 2: Build from Source

#### Prerequisites
- [.NET 8.0 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- Git

#### Build Steps
1. Clone the repository:
   ```bash
   git clone https://github.com/Xpycode/syncthingStatus.git
   cd syncthingStatus/2_Windows/SyncthingStatusWindows
   ```

2. Build the project:
   ```bash
   dotnet build -c Release
   ```

3. Run the application:
   ```bash
   dotnet run
   ```

4. Or publish a self-contained executable:
   ```bash
   dotnet publish -c Release -r win-x64 --self-contained true
   ```

   The executable will be in `bin/Release/net8.0-windows/win-x64/publish/`

## Usage

### First Launch
On first launch, the app will automatically try to discover your Syncthing API key from these locations:
- `%LocalAppData%\Syncthing\config.xml`
- `%UserProfile%\.config\syncthing\config.xml`
- `%AppData%\Syncthing\config.xml`

If automatic discovery fails, you'll see a notification. Right-click the tray icon and select "Settings" to configure manually.

### System Tray Icon
- **Left Click**: Show quick status popup
- **Double Click**: Open detailed status window
- **Right Click**: Show context menu
  - Open Status Window
  - Settings
  - Refresh
  - Exit

### Finding Your API Key
If you need to enter the API key manually:
1. Open Syncthing's web interface (usually http://127.0.0.1:8384)
2. Go to **Actions → Settings**
3. Click on the **GUI** tab
4. Copy the **API Key**
5. Paste it into the Settings window in Syncthing Status

### Connecting to Remote Syncthing
To monitor a Syncthing instance on another machine:
1. Right-click the tray icon and select "Settings"
2. Enter the remote URL (e.g., `http://192.168.1.100:8384`)
3. Enter the API key from the remote Syncthing instance
4. Click "Save"

## Running at Startup

To make Syncthing Status start automatically with Windows:

1. Press `Win + R` to open the Run dialog
2. Type `shell:startup` and press Enter
3. Create a shortcut to `SyncthingStatus.exe` in the Startup folder

## Technical Details

Built with:
- **.NET 8.0** for modern, cross-platform capabilities
- **Windows Forms** for native Windows UI
- **System.Text.Json** for efficient JSON parsing
- **HttpClient** for async API calls

The app queries the following Syncthing REST API endpoints:
- `/rest/system/status` - System information and uptime
- `/rest/system/version` - Syncthing version
- `/rest/system/config` - Device and folder configuration
- `/rest/system/connections` - Connection status for devices
- `/rest/db/status` - Per-folder synchronization status
- `/rest/db/completion` - Per-device completion percentage

## Privacy

- No data collection or telemetry
- All data stays local on your machine
- API keys are stored in application memory only (not persisted)
- Open source - audit the code yourself

## Troubleshooting

### App won't connect to Syncthing
1. Ensure Syncthing is running
2. Check that you can access the Syncthing web interface
3. Verify the Base URL in Settings
4. Ensure the API key is correct

### API key not auto-discovered
The app looks for Syncthing's config.xml in standard locations. If your Syncthing installation uses a custom location, you'll need to enter the API key manually in Settings.

### Icon doesn't appear in system tray
- Check Windows notification area settings
- Right-click the taskbar → Taskbar settings → Other system tray icons
- Ensure Syncthing Status is set to show

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Related Projects

- [macOS Version](../1_Xcode/) - Native macOS menu bar application built with Swift

## License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.

## Acknowledgments

- [Syncthing](https://syncthing.net) - The amazing file synchronization tool this app monitors
- Built with Microsoft's .NET framework for optimal Windows integration

## Support

If you encounter any issues or have suggestions, please [open an issue](https://github.com/Xpycode/syncthingStatus/issues) on GitHub.

---

Made with ❤️ for the Syncthing community
