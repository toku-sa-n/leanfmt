import Lean
import Leanfmt.FormatError
import Leanfmt.Printer
import Leanfmt.FormatConfig
import Leanfmt.AST.Module
import Leanfmt.Options

namespace Leanfmt.CLI

open Leanfmt (Options ValidationError)

def errorCode : UInt32 := 1

def successCode : UInt32 := 0

def helpText : String := r#"leanfmt - A fast, opinionated code formatter for Lean 4

USAGE:
    leanfmt [OPTIONS] [FILES...]

DESCRIPTION:
    leanfmt automatically formats Lean 4 source code according to consistent
    style rules. It helps maintain uniform code style across your projects.

OPTIONS:
    -c, --check       Check if files are formatted without modifying them
                      Exit with status 1 if any files need formatting

    -i, --in-place    Format files in-place, overwriting the original files
                      Cannot be used together with --check

    -h, --help        Display this help message and exit

ARGUMENTS:
    [FILES...]        One or more Lean source files to format
                      If no files are specified, reads from stdin

MODES OF OPERATION:
    1. Format to stdout (default):
       Outputs formatted code to standard output without modifying files

    2. Format check (--check):
       Verifies if files are already formatted. Lists unformatted files
       to stderr and exits with status 1 if any need formatting

    3. In-place formatting (--in-place):
       Modifies the source files directly with formatted content

EXAMPLES:
    # Format a single file to stdout
    leanfmt Main.lean

    # Format multiple files to stdout
    leanfmt src/File1.lean src/File2.lean

    # Check if files are formatted (CI/CD use case)
    leanfmt --check src/**/*.lean

    # Format all Lean files in-place
    leanfmt --in-place *.lean

    # Format code from stdin
    echo 'def foo := 42' | leanfmt

    # Read from file, output formatted version to another file
    leanfmt input.lean > formatted.lean

EXIT STATUS:
    0    Success - all operations completed successfully
    1    Failure - formatting errors or unformatted files found (with --check)

For more information, visit: https://github.com/toku-sa-n/leanfmt"#

def showHelp : IO Unit := do
  IO.print helpText

def formatFile (path : String) : IO String := do
  let source ← IO.FS.readFile path
  Leanfmt.AST.Module.parse source path >>= Leanfmt.runFormatter

def isFormatted (path : String) : IO Bool := do
  let source ← IO.FS.readFile path
  formatFile path |>.map (· == source)

def formatStdin : IO UInt32 := do
  try
    let source ← (← IO.getStdin).readToEnd
    Leanfmt.AST.Module.parse source "<stdin>"
      >>= Leanfmt.runFormatter
      >>= IO.print
    return successCode
  catch e =>
    IO.eprintln s!"Error reading from stdin: {e}"
    return errorCode

def checkFiles (files : Array String) : IO UInt32 := do
  let mut hasUnformatted := false

  for file in files do
    try
      if ← System.FilePath.isDir file then
        throw <| IO.userError s!"{file} is a directory, not a file"

      if !(← isFormatted file) then
        IO.eprintln s!"{file} is not formatted"
        hasUnformatted := true
    catch e =>
      IO.eprintln s!"Error checking {file}: {e}"
      return errorCode

  return if hasUnformatted then errorCode else successCode

def formatFilesToStdout (files : Array String) : IO UInt32 := do
  for file in files do
    try
      if ← System.FilePath.isDir file then
        throw <| IO.userError s!"{file} is a directory, not a file"

      formatFile file >>= IO.print
    catch e =>
      IO.eprintln s!"Error formatting {file}: {e}"
      return errorCode

  return successCode

def formatInPlace (files : Array String) : IO UInt32 := do
  for file in files do
    try
      if ← System.FilePath.isDir file then
        throw <| IO.userError s!"{file} is a directory, not a file"

      formatFile file >>= IO.FS.writeFile file
    catch e =>
      IO.eprintln s!"Error formatting {file} in-place: {e}"
      return errorCode

  return successCode


def runWith (opts : Options) : IO UInt32 := do
  if opts.getShowHelp then
    showHelp *> pure successCode
  else
    let files := opts.getFiles
    if files.isEmpty then
      formatStdin
    else if opts.getCheckMode then
      checkFiles files
    else if opts.getInPlaceMode then
      formatInPlace files
    else
      formatFilesToStdout files

def main (args : Array String) : IO UInt32 := do
  match Options.parseArguments args with
  | .error err =>
    IO.eprintln s!"Error: {err}"
    return errorCode
  | .ok options =>
    runWith options

end Leanfmt.CLI
