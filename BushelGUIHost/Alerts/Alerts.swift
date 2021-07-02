import BushelRT

public func runAlert(heading: String, message: String, title: String, suspension: NSAppleEventManager.SuspensionID) {
    let rt = Runtime()
    
    let wc = AlertWC(windowNibName: "AlertWC")
    
    wc.loadWindow()
    wc.heading = heading
    wc.message = message
    
    let window = wc.window!
    window.title = title
    
    display(window: window) {
        returnResultToSender(
            wc.response.map { RT_String(rt, value: $0) } ?? rt.missing,
            for: suspension
        )
    }
}
