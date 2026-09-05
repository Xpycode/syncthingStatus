import ApplicationServices
import Foundation
let args = CommandLine.arguments
guard args.count == 3, let pid = Int32(args[1]) else { exit(2) }
let app = AXUIElementCreateApplication(pid)
func attribute(_ element: AXUIElement, _ name: CFString) -> AnyObject? {
    var result: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name, &result) == .success else { return nil }
    return result
}
var elements: [AXUIElement] = []
func walk(_ element: AXUIElement, depth: Int) {
    guard depth < 30 else { return }
    elements.append(element)
    for child in attribute(element, kAXChildrenAttribute as CFString) as? [AXUIElement] ?? [] { walk(child, depth: depth+1) }
}
walk(app, depth: 0)
var target: AXUIElement?
var foundDelete = false
for element in elements {
    let title = attribute(element, kAXTitleAttribute as CFString) as? String ?? ""
    let value = attribute(element, kAXValueAttribute as CFString) as? String ?? ""
    let role = attribute(element, kAXRoleAttribute as CFString) as? String ?? ""
    if role == kAXScrollAreaRole as String { print("scrollArea=true") }
    if value.contains("Configured folder root:") { print("rootAndConsequencesText=" + value.replacingOccurrences(of: "\n", with: "|")) }
    if role == kAXTextAreaRole as String { print("selectionText=" + value.replacingOccurrences(of: "\n", with: "|")) }
    if role == kAXButtonRole as String, title == "Delete Permanently" {
        print("deleteEnabled=\(attribute(element, kAXEnabledAttribute as CFString) as? Bool ?? false)")
        foundDelete = true
    }
    if role == kAXButtonRole as String, title == args[2] { target = element }
}
guard foundDelete, let target else { exit(1) }
print("press=\(AXUIElementPerformAction(target, kAXPressAction as CFString).rawValue)")
