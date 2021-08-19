import os.log
import os.signpost

let logSubsystem = "ca.igregory.BushelSourceEditor"
let poi = OSLog(
    subsystem: logSubsystem,
    category: .pointsOfInterest
)

func signpostBegin(name: StaticString = #function) {
    os_signpost(.begin, log: poi, name: name)
}
func signpostEnd(name: StaticString = #function) {
    os_signpost(.end, log: poi, name: name)
}
