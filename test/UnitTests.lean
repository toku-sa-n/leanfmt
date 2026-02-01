import Leanfmt
import Leanfmt.Options
import Leanfmt.AST.Module

open Leanfmt

private def assert (cond : Bool) (msg : String) : IO Unit :=
  if cond then
    pure ()
  else
    throw <| IO.userError msg

private def expectOk (res : Except ValidationError Options) (msg : String) : IO Options :=
  match res with
  | .ok opts => pure opts
  | .error err => throw <| IO.userError s!"{msg}: unexpected error {err}"

private def expectErr
    (res : Except ValidationError Options)
    (pred : ValidationError → Bool)
    (msg : String) : IO Unit :=
  match res with
  | .error err =>
      assert (pred err) s!"{msg}: wrong error {err}"
  | .ok _ =>
      throw <| IO.userError s!"{msg}: expected error"

private def testOptions : IO Unit := do
  let optsEmpty ← expectOk (Options.parseArguments #[]) "empty args"
  assert (!optsEmpty.getCheckMode) "empty args: checkMode should be false"
  assert (!optsEmpty.getInPlaceMode) "empty args: inPlaceMode should be false"
  assert (optsEmpty.getFiles.isEmpty) "empty args: files should be empty"

  let optsCheck ← expectOk (Options.parseArguments #["--check"]) "check without files"
  assert optsCheck.getCheckMode "--check should enable checkMode"
  assert (!optsCheck.getInPlaceMode) "--check should not enable inPlaceMode"
  assert optsCheck.getFiles.isEmpty "--check without files should keep files empty"

  let optsInPlace ← expectOk (Options.parseArguments #["--in-place", "foo.lean"]) "in-place with file"
  assert (!optsInPlace.getCheckMode) "--in-place should not enable checkMode"
  assert optsInPlace.getInPlaceMode "--in-place should enable inPlaceMode"
  assert (optsInPlace.getFiles == #["foo.lean"]) "--in-place should keep file list"

  expectErr (Options.parseArguments #["--in-place"]) (fun err =>
    match err with
    | .missingFiles => true
    | _ => false
  ) "--in-place without files"

  expectErr (Options.parseArguments #["--check", "--in-place"]) (fun err =>
    match err with
    | .conflictingModes => true
    | _ => false
  ) "conflicting modes"

  expectErr (Options.parseArguments #["--nope"]) (fun err =>
    match err with
    | .unknownOption _ => true
    | _ => false
  ) "unknown option"

  let optsStdin ← expectOk (Options.parseArguments #["-"]) "stdin only"
  assert (optsStdin.getFiles == #["-"]) "stdin only should keep '-' in files"

  let optsOrdered ← expectOk (Options.parseArguments #["foo.lean", "-", "bar.lean"]) "stdin order"
  assert (optsOrdered.getFiles == #["foo.lean", "-", "bar.lean"]) "stdin order should be preserved"

  expectErr (Options.parseArguments #["-", "-"]) (fun err =>
    match err with
    | .multipleStdin => true
    | _ => false
  ) "multiple stdin"

  expectErr (Options.parseArguments #["--in-place", "-"]) (fun err =>
    match err with
    | .stdinInPlace => true
    | _ => false
  ) "stdin with in-place"

private def testFormatter : IO Unit := do
  let module ← Leanfmt.AST.Module.parse "def   foo   :   Nat   :=   42\n" "<stdin>"
  let out1 ← Leanfmt.runFormatter module
  let out2 ← Leanfmt.runFormatter module
  assert (out1 == out2) "formatter should be deterministic"
  assert (out1.endsWith "\n") "formatter output should end with newline"
  assert (!out1.endsWith "\n\n") "formatter output should have single trailing newline"

  let module2 ← Leanfmt.AST.Module.parse out1 "<stdin>"
  let out3 ← Leanfmt.runFormatter module2
  assert (out1 == out3) "formatter should be idempotent"

private def testParseError : IO Unit := do
  let failed ←
    try
      let _ ← Leanfmt.AST.Module.parse "def :=\n" "<stdin>"
      pure false
    catch _ =>
      pure true
  assert failed "invalid syntax should raise error"

def main : IO Unit := do
  testOptions
  testFormatter
  testParseError
  IO.println "Unit tests passed"
