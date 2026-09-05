import ApplicationServices
import Foundation
let args = CommandLine.arguments
guard args.count == 3, let pid = Int32(args[1]) else { exit(2) }
func attr(_ e: AXUIElement, _ key: String) -> AnyObject? { var out: CFTypeRef?; guard AXUIElementCopyAttributeValue(e, key as CFString, &out) == .success else { return nil }; return out }
var nodes: [[String:Any]]=[]
var target: AXUIElement?
func walk(_ e: AXUIElement, _ depth: Int) {
    guard depth<40 else { return }
    let role=attr(e,kAXRoleAttribute) as? String ?? ""
    let title=attr(e,kAXTitleAttribute) as? String ?? ""
    let label=attr(e,kAXDescriptionAttribute) as? String ?? ""
    let enabled=attr(e,kAXEnabledAttribute) as? Bool ?? false
    let value=attr(e,kAXValueAttribute)
    var node:[String:Any]=["role":role,"title":title,"label":label,"enabled":enabled]
    if let value=value as? String { node["value"]=value }
    else if let value=value as? NSNumber { node["value"]=value }
    if !title.isEmpty || !label.isEmpty || node["value"] != nil { nodes.append(node) }
    if args[2] != "dump", enabled, [kAXButtonRole,kAXCheckBoxRole].contains(role), title == args[2] || label == args[2] { target=e }
    for child in attr(e,kAXChildrenAttribute) as? [AXUIElement] ?? [] { walk(child,depth+1) }
}
let app = AXUIElementCreateApplication(pid)
for window in attr(app,kAXWindowsAttribute) as? [AXUIElement] ?? [] { walk(window,0) }
if args[2] == "dump" { print(String(data:try! JSONSerialization.data(withJSONObject:nodes,options:[.sortedKeys]),encoding:.utf8)!) }
else if let target { print("press=\(AXUIElementPerformAction(target,kAXPressAction as CFString).rawValue)") }
else { exit(1) }
