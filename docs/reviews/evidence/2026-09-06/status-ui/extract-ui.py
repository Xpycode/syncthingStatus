#!/usr/bin/env python3
from pathlib import Path
import hashlib
import json
import textwrap

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parents[4] / "01_Project" / "syncthingStatus"


def slice_between(text: str, start: str, end: str) -> str:
    begin = text.index(start)
    return text[begin:text.index(end, begin)]


views = (SOURCE / "Views.swift").read_text()
parts = [
    slice_between(views, "struct DeviceTransferSpeedChartView:", "struct TotalTransferSpeedChartView:"),
    slice_between(views, "struct DeviceStatusRow:", "// MARK: - Device Detail Helper Views"),
    slice_between(views, "struct DeviceDetailedConnectedView:", "struct DeviceDetailedDisconnectedView:"),
    slice_between(views, "struct DeviceDetailedDisconnectedView:", "// MARK: - Folder Detail Helper Views"),
    slice_between(views, "struct FolderDetailedContentView:", "// MARK: - Helper Views"),
    slice_between(views, "struct InfoRow:", "struct FolderStatusRow:"),
    slice_between(views, "struct FolderStatusRow:", "// MARK: - Stuck Deletes Cleanup Window"),
]
settings_section = textwrap.dedent(
    slice_between(views, '            Section("Sync Completion") {', '\n\n            Section("Monitoring") {')
)
parts.append(
    "struct ProductionSyncCompletionSection: View {\n"
    "    var body: some View {\n"
    "        Form {\n"
    + textwrap.indent(settings_section, "            ")
    + "\n        }\n"
    "        .formStyle(.grouped)\n"
    "    }\n"
    "}"
)

extracted = "import AppKit\nimport Charts\nimport Foundation\nimport SwiftUI\n\n" + "\n".join(parts)
# Normalize whitespace in the preserved excerpt; hashes below retain original source bytes.
extracted = "\n".join(line.rstrip() for line in extracted.splitlines()) + "\n"
(HERE / "ProductionStatusRows.swift").write_text(extracted)

hashes = {
    "Views.swift": {
        "fileSHA256": hashlib.sha256(views.encode()).hexdigest(),
        "sliceSHA256": hashlib.sha256("\n".join(parts).encode()).hexdigest(),
    }
}
for name in [
    "App.swift",
    "Client.swift",
    "Models.swift",
    "Helpers.swift",
    "SyncStatusPolicy.swift",
    "SyncStatusPresentation.swift",
    "SyncthingSettings.swift",
    "SyncthingStatusIcon.swift",
]:
    data = (SOURCE / name).read_bytes()
    hashes[name] = {"fileSHA256": hashlib.sha256(data).hexdigest()}
(HERE / "production-source-hashes.json").write_text(json.dumps(hashes, indent=2) + "\n")
