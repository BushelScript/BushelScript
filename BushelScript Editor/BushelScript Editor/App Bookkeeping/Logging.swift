// BushelScript Editor application
// © 2019-2020 Ian A. Gregory.
// See file LICENSE.txt for licensing information.

import os

let logSubsystem = "com.justcheesy.BushelScript-Editor"
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
