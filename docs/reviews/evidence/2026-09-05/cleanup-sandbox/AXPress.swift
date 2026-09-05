import ApplicationServices
import Foundation
let args = CommandLine.arguments
guard args.count == 2, let pid = Int32(args[1]) else { exit(2) }
let app = AXUIElementCreateApplication(pid)
func attribute(_ element: AXUIElement, _ name: CFString) -> AnyObject? {
    var result: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name, &result) == .success else { return nil }
    return result
}
func press(_ element: AXUIElement, depth: Int) -> Bool {
    guard depth < 20 else { return false }
    let title = attribute(element, kAXTitleAttribute as CFString) as? String ?? ""
    let role = attribute(element, kAXRoleAttribute as CFString) as? String ?? ""
    if role == (kAXButtonRole as String), title == "Grant Fixture" {
        print("press=\(AXUIElementPerformAction(element, kAXPressAction as CFString).rawValue)")
        return true
    }
    for child in attribute(element, kAXChildrenAttribute as CFString) as? [AXUIElement] ?? [] {
        if press(child, depth: depth + 1) { return true }
    }
    return false
}
exit(press(app, depth: 0) ? 0 : 1)
