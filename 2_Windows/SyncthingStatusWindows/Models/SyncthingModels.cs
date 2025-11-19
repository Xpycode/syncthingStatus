using System;
using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace SyncthingStatusWindows.Models
{
    // System Status
    public class SystemStatus
    {
        [JsonPropertyName("myID")]
        public string MyID { get; set; } = "";

        [JsonPropertyName("tilde")]
        public string? Tilde { get; set; }

        [JsonPropertyName("uptime")]
        public int Uptime { get; set; }

        [JsonPropertyName("version")]
        public string? Version { get; set; }
    }

    // Version Info
    public class VersionInfo
    {
        [JsonPropertyName("version")]
        public string Version { get; set; } = "";
    }

    // Config
    public class SyncthingConfig
    {
        [JsonPropertyName("devices")]
        public List<Device> Devices { get; set; } = new();

        [JsonPropertyName("folders")]
        public List<Folder> Folders { get; set; } = new();
    }

    public class Device
    {
        [JsonPropertyName("deviceID")]
        public string DeviceID { get; set; } = "";

        [JsonPropertyName("name")]
        public string Name { get; set; } = "";

        [JsonPropertyName("addresses")]
        public List<string> Addresses { get; set; } = new();

        [JsonPropertyName("paused")]
        public bool Paused { get; set; }
    }

    public class Folder
    {
        [JsonPropertyName("id")]
        public string ID { get; set; } = "";

        [JsonPropertyName("label")]
        public string Label { get; set; } = "";

        [JsonPropertyName("path")]
        public string Path { get; set; } = "";

        [JsonPropertyName("devices")]
        public List<FolderDevice> Devices { get; set; } = new();

        [JsonPropertyName("paused")]
        public bool Paused { get; set; }
    }

    public class FolderDevice
    {
        [JsonPropertyName("deviceID")]
        public string DeviceID { get; set; } = "";
    }

    // Connections
    public class ConnectionsResponse
    {
        [JsonPropertyName("connections")]
        public Dictionary<string, Connection> Connections { get; set; } = new();

        [JsonPropertyName("total")]
        public ConnectionTotal? Total { get; set; }
    }

    public class Connection
    {
        [JsonPropertyName("connected")]
        public bool Connected { get; set; }

        [JsonPropertyName("address")]
        public string? Address { get; set; }

        [JsonPropertyName("clientVersion")]
        public string? ClientVersion { get; set; }

        [JsonPropertyName("type")]
        public string? Type { get; set; }

        [JsonPropertyName("inBytesTotal")]
        public long InBytesTotal { get; set; }

        [JsonPropertyName("outBytesTotal")]
        public long OutBytesTotal { get; set; }
    }

    public class ConnectionTotal
    {
        [JsonPropertyName("connected")]
        public int? Connected { get; set; }

        [JsonPropertyName("paused")]
        public int? Paused { get; set; }

        [JsonPropertyName("inBytesTotal")]
        public long? InBytesTotal { get; set; }

        [JsonPropertyName("outBytesTotal")]
        public long? OutBytesTotal { get; set; }
    }

    // Folder Status
    public class FolderStatus
    {
        [JsonPropertyName("globalFiles")]
        public int GlobalFiles { get; set; }

        [JsonPropertyName("globalBytes")]
        public long GlobalBytes { get; set; }

        [JsonPropertyName("localFiles")]
        public int LocalFiles { get; set; }

        [JsonPropertyName("localBytes")]
        public long LocalBytes { get; set; }

        [JsonPropertyName("needFiles")]
        public int NeedFiles { get; set; }

        [JsonPropertyName("needBytes")]
        public long NeedBytes { get; set; }

        [JsonPropertyName("state")]
        public string State { get; set; } = "";

        [JsonPropertyName("lastScan")]
        public string? LastScan { get; set; }
    }

    // Device Completion
    public class DeviceCompletion
    {
        [JsonPropertyName("completion")]
        public double Completion { get; set; }

        [JsonPropertyName("globalBytes")]
        public long GlobalBytes { get; set; }

        [JsonPropertyName("needBytes")]
        public long NeedBytes { get; set; }
    }

    // Transfer Rates (computed client-side)
    public class TransferRates
    {
        public double DownloadRate { get; set; }  // bytes per second
        public double UploadRate { get; set; }    // bytes per second
    }
}
