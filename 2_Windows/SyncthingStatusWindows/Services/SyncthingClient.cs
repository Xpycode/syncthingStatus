using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text.Json;
using System.Threading.Tasks;
using SyncthingStatusWindows.Models;

namespace SyncthingStatusWindows.Services
{
    public class SyncthingClient : IDisposable
    {
        private readonly HttpClient _httpClient;
        private string _baseUrl = "http://127.0.0.1:8384";
        private string? _apiKey;

        // Cached data
        public bool IsConnected { get; private set; }
        public SystemStatus? SystemStatus { get; private set; }
        public string? SyncthingVersion { get; private set; }
        public List<Device> Devices { get; private set; } = new();
        public List<Folder> Folders { get; private set; } = new();
        public Dictionary<string, Connection> Connections { get; private set; } = new();
        public Dictionary<string, FolderStatus> FolderStatuses { get; private set; } = new();
        public Dictionary<string, DeviceCompletion> DeviceCompletions { get; private set; } = new();
        public Dictionary<string, TransferRates> TransferRates { get; private set; } = new();
        public string? LastErrorMessage { get; private set; }
        public string LocalDeviceName { get; private set; } = "";

        // Transfer rate tracking
        private Dictionary<string, Connection> _previousConnections = new();
        private DateTime? _lastUpdateTime;

        // Events for UI updates
        public event EventHandler? DataUpdated;

        public SyncthingClient()
        {
            _httpClient = new HttpClient
            {
                Timeout = TimeSpan.FromSeconds(10)
            };
        }

        public void Configure(string baseUrl, string apiKey)
        {
            _baseUrl = baseUrl.TrimEnd('/');
            _apiKey = apiKey;
            _httpClient.DefaultRequestHeaders.Clear();
            _httpClient.DefaultRequestHeaders.Add("X-API-Key", _apiKey);
        }

        private string GetEndpointUrl(string path)
        {
            return $"{_baseUrl}/rest/{path.TrimStart('/')}";
        }

        public async Task<bool> RefreshAsync()
        {
            if (string.IsNullOrWhiteSpace(_apiKey))
            {
                LastErrorMessage = "API key is not configured";
                IsConnected = false;
                return false;
            }

            try
            {
                // Fetch system status first to verify connection
                await FetchStatusAsync();

                if (!IsConnected || SystemStatus == null)
                {
                    return false;
                }

                // Fetch all other data in parallel
                var tasks = new List<Task>
                {
                    FetchVersionAsync(),
                    FetchConfigAsync(SystemStatus.MyID),
                    FetchConnectionsAsync()
                };

                await Task.WhenAll(tasks);

                // Fetch folder statuses and device completions
                await FetchFolderStatusesAsync();
                await FetchDeviceCompletionsAsync();

                DataUpdated?.Invoke(this, EventArgs.Empty);
                return true;
            }
            catch (Exception ex)
            {
                LastErrorMessage = $"Refresh failed: {ex.Message}";
                IsConnected = false;
                return false;
            }
        }

        private async Task FetchStatusAsync()
        {
            try
            {
                var url = GetEndpointUrl("system/status");
                var response = await _httpClient.GetAsync(url);

                if (!response.IsSuccessStatusCode)
                {
                    IsConnected = false;
                    LastErrorMessage = $"HTTP {(int)response.StatusCode}: {response.ReasonPhrase}";
                    return;
                }

                var json = await response.Content.ReadAsStringAsync();
                SystemStatus = JsonSerializer.Deserialize<SystemStatus>(json);
                IsConnected = true;
                LastErrorMessage = null;
            }
            catch (HttpRequestException ex)
            {
                IsConnected = false;
                LastErrorMessage = $"Cannot connect to Syncthing: {ex.Message}";
            }
            catch (Exception ex)
            {
                IsConnected = false;
                LastErrorMessage = $"Error: {ex.Message}";
            }
        }

        private async Task FetchVersionAsync()
        {
            try
            {
                var url = GetEndpointUrl("system/version");
                var response = await _httpClient.GetAsync(url);

                if (response.IsSuccessStatusCode)
                {
                    var json = await response.Content.ReadAsStringAsync();
                    var versionInfo = JsonSerializer.Deserialize<VersionInfo>(json);
                    SyncthingVersion = versionInfo?.Version;
                }
            }
            catch
            {
                // Version fetch is non-critical
                SyncthingVersion = null;
            }
        }

        private async Task FetchConfigAsync(string localDeviceId)
        {
            try
            {
                var url = GetEndpointUrl("system/config");
                var response = await _httpClient.GetAsync(url);

                if (!response.IsSuccessStatusCode) return;

                var json = await response.Content.ReadAsStringAsync();
                var config = JsonSerializer.Deserialize<SyncthingConfig>(json);

                if (config != null)
                {
                    // Find local device name
                    var localDevice = config.Devices.FirstOrDefault(d => d.DeviceID == localDeviceId);
                    if (localDevice != null)
                    {
                        LocalDeviceName = localDevice.Name;
                    }

                    // Filter out local device from device list
                    Devices = config.Devices.Where(d => d.DeviceID != localDeviceId).ToList();
                    Folders = config.Folders;
                }
            }
            catch
            {
                // Config fetch failure is handled by connection status
            }
        }

        private async Task FetchConnectionsAsync()
        {
            try
            {
                var url = GetEndpointUrl("system/connections");
                var response = await _httpClient.GetAsync(url);

                if (!response.IsSuccessStatusCode) return;

                var json = await response.Content.ReadAsStringAsync();
                var connectionsResponse = JsonSerializer.Deserialize<ConnectionsResponse>(json);

                if (connectionsResponse != null)
                {
                    Connections = connectionsResponse.Connections;
                    CalculateTransferRates(Connections);
                }
            }
            catch
            {
                // Connection fetch failure is handled by connection status
            }
        }

        private void CalculateTransferRates(Dictionary<string, Connection> newConnections)
        {
            var currentTime = DateTime.Now;

            if (_lastUpdateTime == null)
            {
                _previousConnections = newConnections;
                _lastUpdateTime = currentTime;
                return;
            }

            var timeDelta = (currentTime - _lastUpdateTime.Value).TotalSeconds;
            if (timeDelta <= 0) return;

            var updatedRates = new Dictionary<string, TransferRates>();

            foreach (var (deviceId, newConnection) in newConnections)
            {
                if (!newConnection.Connected || !_previousConnections.TryGetValue(deviceId, out var oldConnection))
                {
                    updatedRates[deviceId] = new TransferRates();
                    continue;
                }

                var bytesReceived = Math.Max(0, newConnection.InBytesTotal - oldConnection.InBytesTotal);
                var bytesSent = Math.Max(0, newConnection.OutBytesTotal - oldConnection.OutBytesTotal);

                updatedRates[deviceId] = new TransferRates
                {
                    DownloadRate = Math.Max(0, bytesReceived / timeDelta),
                    UploadRate = Math.Max(0, bytesSent / timeDelta)
                };
            }

            TransferRates = updatedRates;
            _previousConnections = newConnections;
            _lastUpdateTime = currentTime;
        }

        private async Task FetchFolderStatusesAsync()
        {
            var statuses = new Dictionary<string, FolderStatus>();

            foreach (var folder in Folders)
            {
                try
                {
                    var url = GetEndpointUrl($"db/status?folder={Uri.EscapeDataString(folder.ID)}");
                    var response = await _httpClient.GetAsync(url);

                    if (response.IsSuccessStatusCode)
                    {
                        var json = await response.Content.ReadAsStringAsync();
                        var status = JsonSerializer.Deserialize<FolderStatus>(json);
                        if (status != null)
                        {
                            statuses[folder.ID] = status;
                        }
                    }
                }
                catch
                {
                    // Individual folder status failures are non-critical
                }
            }

            FolderStatuses = statuses;
        }

        private async Task FetchDeviceCompletionsAsync()
        {
            var completions = new Dictionary<string, DeviceCompletion>();

            foreach (var device in Devices)
            {
                try
                {
                    var url = GetEndpointUrl($"db/completion?device={Uri.EscapeDataString(device.DeviceID)}");
                    var response = await _httpClient.GetAsync(url);

                    if (response.IsSuccessStatusCode)
                    {
                        var json = await response.Content.ReadAsStringAsync();
                        var completion = JsonSerializer.Deserialize<DeviceCompletion>(json);
                        if (completion != null)
                        {
                            completions[device.DeviceID] = completion;
                        }
                    }
                }
                catch
                {
                    // Individual device completion failures are non-critical
                }
            }

            DeviceCompletions = completions;
        }

        public double GetCurrentDownloadSpeed()
        {
            return TransferRates.Values.Sum(r => r.DownloadRate);
        }

        public double GetCurrentUploadSpeed()
        {
            return TransferRates.Values.Sum(r => r.UploadRate);
        }

        public int GetConnectedDevicesCount()
        {
            return Connections.Count(c => c.Value.Connected);
        }

        public long GetTotalSyncedData()
        {
            return FolderStatuses.Values.Sum(f => f.LocalBytes);
        }

        public void Dispose()
        {
            _httpClient?.Dispose();
        }
    }
}
