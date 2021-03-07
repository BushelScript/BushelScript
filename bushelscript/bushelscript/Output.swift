// BushelScript command-line interface.
// See file main.swift for copyright and licensing information.

import Foundation

func printUsage() {
    print("""
Usage:
    bushelscript [-e script] [script-file]
    bushelscript (-v | --version)
    bushelscript (-h | --help)

Arguments:
    script-file             Specifies a script file to run.

Options:
    -e                      Specifies a line of script code to run.
    -R, --no-result         Disables printing the final result to stdout.
    -v, --version           Displays version of this command-line tool and of installed BushelScript frameworks, then exits.
    -h, --help              Prints this help text, then exits.
""")
}
