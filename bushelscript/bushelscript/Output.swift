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
    -v, --version           Display version of this command-line tool and of installed BushelScript frameworks, then exit.
    -h, --help              Print this help text, then exit.
""")
}
