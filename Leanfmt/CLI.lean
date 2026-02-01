import Lean
import Leanfmt.FormatError
import Leanfmt.Printer
import Leanfmt.FormatConfig
import Leanfmt.AST.Module
import Leanfmt.Options

namespace Leanfmt.CLI
open Leanfmt (Options ValidationError)
def errorCode : UInt32 :=
  1
def successCode : UInt32 :=
  0
def helpText : String :=
  r#"leanfmt - A fast, opinionated code formatter for Lean 4
    
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
inductive InputSource where
  | stdin : InputSource
  | file (path : String) : InputSource
  deriving Inhabited
def InputSource.label : InputSource → String
  | .stdin => "<stdin>"
  | .file path => path
def resolveInputs (files : Array String) : Array InputSource :=
  if files.isEmpty then #[.stdin]
  else files.map fun file => if file == "-" then .stdin else .file file
def countFileInputs (inputs : Array InputSource) : Nat :=
  inputs.foldl
    (fun acc input =>
      match input with
      | .file _ => acc + 1
      | .stdin => acc)
    0
def readSource (input : InputSource) : IO String := do
  match input with
  | .stdin =>
    (← IO.getStdin).readToEnd
  | .file path =>
    if ← System.FilePath.isDir path then 
      throw <| IO.userError s! "{path} is a directory, not a file"
    IO.FS.readFile path
def formatSource (source : String) (label : String) : IO String := do
  Leanfmt.AST.Module.parse source label >>= Leanfmt.runFormatter
def formatInput (input : InputSource) : IO (String × String) := do
  let label := input.label
  let source ← readSource input
  let formatted ← formatSource source label
  return (source, formatted)
def checkInputs (inputs : Array InputSource) : IO UInt32 := do
  let mut hasUnformatted := false
  for input in inputs do
    let label := input.label
    try
      let (source, formatted) ← formatInput input
      if source != formatted then 
        IO.eprintln s! "{label} is not formatted"
        hasUnformatted := true
    catch e =>
      IO.eprintln s! "Error checking {label }: {e}"
      return errorCode
  return if hasUnformatted then errorCode else successCode
def formatInputsToStdout (inputs : Array InputSource) : IO UInt32 := do
  let fileCount := countFileInputs inputs
  for input in inputs do
    let label := input.label
    try
      let (_, formatted) ← formatInput input
      match input with
      | .file path =>
        if fileCount > 1 then 
          IO.println path
          IO.println ""
      | .stdin =>
        pure ()
      IO.print formatted
    catch e =>
      IO.eprintln s! "Error formatting {label }: {e}"
      return errorCode
  return successCode
def formatInputsInPlace (inputs : Array InputSource) : IO UInt32 := do
  for input in inputs do
    match input with
    | .stdin =>
      IO.eprintln "Error formatting <stdin> in-place: stdin is not supported"
      return errorCode
    | .file path =>
      try
        let source ← readSource input
        let formatted ← formatSource source path
        IO.FS.writeFile path formatted
      catch e =>
        IO.eprintln s! "Error formatting {path } in-place: {e}"
        return errorCode
  return successCode
def runWith (opts : Options) : IO UInt32 := do
  if opts.getShowHelp then 
    showHelp *> pure successCode
  else
    let inputs := resolveInputs opts.getFiles
    if opts.getCheckMode then 
      checkInputs inputs
    else if opts.getInPlaceMode then
      formatInputsInPlace inputs
    else
      formatInputsToStdout inputs
def main (args : Array String) : IO UInt32 := do
  match Options.parseArguments args with
  | .error err =>
    IO.eprintln s! "{err}"
    IO.eprintln helpText
    return errorCode
  | .ok options =>
    runWith options
end Leanfmt.CLI
