import ApplicationServices
import CoreGraphics
import Foundation

let args = CommandLine.arguments
guard args.count == 3, let pid = Int32(args[1]) else { exit(2) }

func attr(_ element: AXUIElement, _ key: String) -> AnyObject? {
    var output: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, key as CFString, &output) == .success else { return nil }
    return output
}

if args[2] == "window-id" {
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    if let window = windows.first(where: { ($0[kCGWindowOwnerPID as String] as? Int32) == pid }),
       let number = window[kCGWindowNumber as String] as? NSNumber {
        print(number)
        exit(0)
    }
    exit(4)
}

var nodes = [[String: Any]]()
var closeButton: AXUIElement?
func walk(_ element: AXUIElement, depth: Int) {
    guard depth < 50 else { return }
    let role = attr(element, kAXRoleAttribute) as? String ?? ""
    let title = attr(element, kAXTitleAttribute) as? String ?? ""
    let label = attr(element, kAXDescriptionAttribute) as? String ?? ""
    let enabled = attr(element, kAXEnabledAttribute) as? Bool ?? false
    let value = attr(element, kAXValueAttribute)
    var node: [String: Any] = ["role": role, "title": title, "label": label, "enabled": enabled]
    if let string = value as? String { node["value"] = string }
    else if let number = value as? NSNumber { node["value"] = number }
    if !title.isEmpty || !label.isEmpty || node["value"] != nil { nodes.append(node) }
    if role == kAXButtonRole, enabled, title == "Close Fixture" || label == "Close Fixture" { closeButton = element }
    for child in attr(element, kAXChildrenAttribute) as? [AXUIElement] ?? [] { walk(child, depth: depth + 1) }
}

let application = AXUIElementCreateApplication(pid)
for window in attr(application, kAXWindowsAttribute) as? [AXUIElement] ?? [] { walk(window, depth: 0) }
if args[2] == "dump" {
    print(String(data: try JSONSerialization.data(withJSONObject: nodes, options: [.prettyPrinted, .sortedKeys]), encoding: .utf8)!)
} else if args[2] == "close", let closeButton {
    print("close=\(AXUIElementPerformAction(closeButton, kAXPressAction as CFString).rawValue)")
} else {
    exit(5)
}
