from pathlib import Path
import hashlib, json
base=Path('/private/tmp/syncthingStatus-sandbox-probe')
source=Path('/Users/sim/ProgrammingProjects/1-macOS/_Published/syncthingStatus/01_Project/syncthingStatus')
parts=[]; hashes={}
for filename,start,end in [('App.swift','final class StuckDeletesWindowController:', '// MARK: - Hosting Controller Helpers'),('Views.swift','struct StuckDeletesView:', 'struct SettingsView:')]:
    data=(source/filename).read_text()
    snippet=data[data.index(start):data.index(end,data.index(start))]
    parts.append(snippet)
    hashes[filename]={'fileSHA256':hashlib.sha256(data.encode()).hexdigest(),'snippetSHA256':hashlib.sha256(snippet.encode()).hexdigest()}
(base/'ProductionCleanupUI.swift').write_text('import AppKit\nimport SwiftUI\nimport Combine\n\n'+'\n'.join(parts))
for filename in ['Client.swift','FolderAccessBookmarks.swift','CleanupConfirmationDialog.swift']:
    hashes[filename]={'fileSHA256':hashlib.sha256((source/filename).read_bytes()).hexdigest()}
(base/'production-source-hashes.json').write_text(json.dumps(hashes,indent=2))
