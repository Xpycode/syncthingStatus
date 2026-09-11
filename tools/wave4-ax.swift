import ApplicationServices
import Foundation

let arguments = CommandLine.arguments
guard arguments.count >= 3, let pid = Int32(arguments[1]) else { exit(2) }

func attribute(_ element: AXUIElement, _ key: String) -> AnyObject? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success else { return nil }
    return value
}

func string(_ element: AXUIElement, _ key: String) -> String {
    attribute(element, key) as? String ?? ""
}

func children(_ element: AXUIElement) -> [AXUIElement] {
    attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
}

func walk(_ element: AXUIElement, depth: Int = 0, visit: (AXUIElement) -> Bool) -> Bool {
    guard depth < 50 else { return false }
    if visit(element) { return true }
    for child in children(element) where walk(child, depth: depth + 1, visit: visit) { return true }
    return false
}

func matches(_ element: AXUIElement, _ name: String) -> Bool {
    string(element, kAXTitleAttribute) == name ||
        string(element, kAXDescriptionAttribute) == name ||
        string(element, kAXValueAttribute) == name
}

let app = AXUIElementCreateApplication(pid)
let roots = attribute(app, kAXWindowsAttribute) as? [AXUIElement] ?? [app]
let command = arguments[2]

if command == "dump" {
    var rows: [[String: Any]] = []
    for root in roots {
        _ = walk(root) { element in
            let role = string(element, kAXRoleAttribute)
            let title = string(element, kAXTitleAttribute)
            let label = string(element, kAXDescriptionAttribute)
            let enabled = attribute(element, kAXEnabledAttribute) as? Bool ?? false
            let value = attribute(element, kAXValueAttribute)
            var row: [String: Any] = ["role": role, "title": title, "label": label, "enabled": enabled]
            if let value = value as? String { row["value"] = value }
            else if let value = value as? NSNumber { row["value"] = value }
            if !title.isEmpty || !label.isEmpty || row["value"] != nil { rows.append(row) }
            return false
        }
    }
    let data = try JSONSerialization.data(withJSONObject: rows, options: [.sortedKeys])
    print(String(decoding: data, as: UTF8.self))
    exit(0)
}

guard arguments.count >= 4 else { exit(2) }
let name = arguments[3]

if command == "press" {
    var result: AXError?
    let found = roots.contains { root in
        walk(root) { element in
            let role = string(element, kAXRoleAttribute)
            guard (attribute(element, kAXEnabledAttribute) as? Bool) == true,
                  [kAXButtonRole, kAXCheckBoxRole, kAXDisclosureTriangleRole, kAXRadioButtonRole].contains(role),
                  matches(element, name) else { return false }
            result = AXUIElementPerformAction(element, kAXPressAction as CFString)
            return true
        }
    }
    guard found, let result else { exit(1) }
    print("press=\(result.rawValue)")
    exit(result == .success ? 0 : 1)
}

if command == "set-disclosure" {
    guard arguments.count == 5, let requested = Int(arguments[4]) else { exit(2) }
    var result: AXError?
    let found = roots.contains { root in
        walk(root) { element in
            guard string(element, kAXRoleAttribute) == kAXDisclosureTriangleRole,
                  matches(element, name) else { return false }
            result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString,
                                                   NSNumber(value: requested))
            return true
        }
    }
    guard found, let result else { exit(1) }
    print("disclosure=\(requested);result=\(result.rawValue)")
    exit(result == .success ? 0 : 1)
}

if command == "set-check" {
    guard arguments.count == 5, let requested = Int(arguments[4]) else { exit(2) }
    var labelElement: AXUIElement?
    for root in roots where labelElement == nil {
        _ = walk(root) { element in
            guard string(element, kAXRoleAttribute) == kAXStaticTextRole, matches(element, name) else { return false }
            labelElement = element
            return true
        }
    }
    guard var current = labelElement else { exit(1) }
    for _ in 0..<5 {
        var checkbox: AXUIElement?
        _ = walk(current, depth: 0) { element in
            guard string(element, kAXRoleAttribute) == kAXCheckBoxRole else { return false }
            checkbox = element
            return true
        }
        if let checkbox {
            let actual = (attribute(checkbox, kAXValueAttribute) as? NSNumber)?.intValue ?? -1
            if actual != requested {
                guard AXUIElementPerformAction(checkbox, kAXPressAction as CFString) == .success else { exit(1) }
            }
            print("check=\(requested)")
            exit(0)
        }
        guard let parent = attribute(current, kAXParentAttribute) else { break }
        current = parent as! AXUIElement
    }
    exit(1)
}

exit(2)
