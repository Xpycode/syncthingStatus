from pathlib import Path
import subprocess
root=Path(__file__).resolve().parents[4]
s=(root/'01_Project/syncthingStatus/Client.swift').read_text()
a=s.index('    func performDeletion(selected: Set<String>) async {');b=s.index('\n    /// Validates',a)
method=s[a:b]
assert 'removeItem(' not in s
assert 'deleteOne(' not in s
view=(root/'01_Project/syncthingStatus/Views.swift').read_text()
row=view[view.index('struct StuckDeletesAlertRow:'):view.index('struct StuckDeletesAlertRow:')+3500]
assert 'Button("Resolve' not in row
assert 'Cleanup temporarily unavailable in 1.6.2' in row
app=(root/'01_Project/syncthingStatus/App.swift').read_text()
entry=app[app.index('    func openStuckDeletesResolution'):app.index('    func showAboutPanel')]
assert 'StuckDeletesWindowController(' not in entry
harness='''import Foundation
final class Controller {
 var lastOutcome: String? = "previous success"
 var lastError: String?
'''+method+'''}
@main struct Check {
 static func main() async throws {
  let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: root) }
  let file=root.appendingPathComponent("sentinel")
  try Data("preserve".utf8).write(to:file)
  let controller=Controller()
  for selected: Set<String> in [[], ["sentinel"], ["../sentinel"], [file.path]] {
   await controller.performDeletion(selected:selected)
   precondition(controller.lastOutcome == nil)
   precondition(controller.lastError?.contains("No files were deleted") == true)
   precondition(try! Data(contentsOf:file) == Data("preserve".utf8))
  }
  print("PASS: production deletion entry refuses 4 selection cases; sentinel preserved; no success outcome; UI entry points disabled; deletion implementation absent")
 }
}
'''
p=Path('/private/tmp/cleanup-disabled.swift');p.write_text(harness)
subprocess.run(['xcrun','swiftc','-parse-as-library',str(p),'-o','/private/tmp/cleanup-disabled'],check=True)
subprocess.run(['/private/tmp/cleanup-disabled'],check=True)
