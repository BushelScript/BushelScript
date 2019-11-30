// BushelScript command-line interface.
//
// © 2019 Ian A. Gregory, licensed under the terms of the GPL v3 or later.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

var invocation = ToolInvocation()

for argument in CommandLine.arguments.dropFirst() {
    var argument = argument[argument.startIndex...]
    if argument.removePrefix("--") {
        parse(longOption: argument)
    } else if argument.removePrefix("-") {
        parse(shortOptions: argument)
    } else {
        parse(argument: argument)
    }
}

do {
    try invocation.run()
} catch {
    print("\(error)")
}
