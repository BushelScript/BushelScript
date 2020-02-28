import BushelRT

public func chooseFrom(list: [String], prompt: String, okButtonName: String, cancelButtonName: String, title: String, suspension: NSAppleEventManager.SuspensionID) {
    
    let wc = ChooseFromWC(windowNibName: "ChooseFromWC")
    
    wc.loadWindow()
    wc.items = list
    wc.prompt = prompt
    wc.okButtonName = okButtonName
    wc.cancelButtonName = cancelButtonName
    
    let window = wc.window!
    window.title = title
    
    display(window: window) {
        returnResultToSender(
            wc.response.map { RT_String(value: $0) } ?? RT_Null.null,
            for: suspension
        )
    }
    
}
