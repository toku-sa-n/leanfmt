import Leanfmt.CLI.Options.ValidationError

namespace Leanfmt

open Leanfmt.CLI.Options (ValidationError)
export Leanfmt.CLI.Options (ValidationError)

structure Options where
  private mk ::
  private checkMode : Bool := false
  private inPlaceMode : Bool := false
  private showHelp : Bool := false
  private files : Array String := #[]

private structure OptionsBuilder where
  checkMode_ : Bool := false
  inPlaceMode_ : Bool := false
  showHelp_ : Bool := false
  files_ : Array String := #[]
  stdinCount_ : Nat := 0

private def OptionsBuilder.checkMode (builder : OptionsBuilder) : OptionsBuilder :=
  { builder with checkMode_ := true }

private def OptionsBuilder.inPlaceMode (builder : OptionsBuilder) : OptionsBuilder :=
  { builder with inPlaceMode_ := true }

private def OptionsBuilder.showHelp (builder : OptionsBuilder) : OptionsBuilder :=
  { builder with showHelp_ := true }

private def OptionsBuilder.addFile (builder : OptionsBuilder) (file : String) : OptionsBuilder :=
  { builder with files_ := builder.files_.push file }

private def OptionsBuilder.addStdin (builder : OptionsBuilder) : OptionsBuilder :=
  { builder with
    files_ := builder.files_.push "-",
    stdinCount_ := builder.stdinCount_ + 1 }

private def OptionsBuilder.build (builder : OptionsBuilder) : Except ValidationError Options := do
  for file in builder.files_ do
    if file.startsWith "-" && file != "-" then
      throw <| ValidationError.unknownOption file

  if builder.checkMode_ && builder.inPlaceMode_ then
    throw ValidationError.conflictingModes

  if builder.stdinCount_ > 1 then
    throw ValidationError.multipleStdin

  if builder.inPlaceMode_ && builder.stdinCount_ > 0 then
    throw ValidationError.stdinInPlace

  if builder.inPlaceMode_ && builder.files_.isEmpty then
    throw ValidationError.missingFiles

  return Options.mk builder.checkMode_ builder.inPlaceMode_ builder.showHelp_ builder.files_

private def OptionsBuilder.parseArguments (args : Array String) : Except ValidationError OptionsBuilder := do
  return args.foldl processArg {}
  where
    processArg (builder : OptionsBuilder) (arg : String) : OptionsBuilder :=
      if arg == "--help" || arg == "-h" then
        builder.showHelp
      else if arg == "--check" || arg == "-c" then
        builder.checkMode
      else if arg == "--in-place" || arg == "-i" then
        builder.inPlaceMode
      else if arg == "-" then
        builder.addStdin
      else
        builder.addFile arg

def Options.getCheckMode (opts : Options) : Bool := opts.checkMode
def Options.getInPlaceMode (opts : Options) : Bool := opts.inPlaceMode
def Options.getShowHelp (opts : Options) : Bool := opts.showHelp
def Options.getFiles (opts : Options) : Array String := opts.files

def Options.isCheckMode (opts : Options) : Bool := opts.checkMode
def Options.isInPlaceMode (opts : Options) : Bool := opts.inPlaceMode
def Options.isShowHelpMode (opts : Options) : Bool := opts.showHelp

def Options.parseArguments (args : Array String) : Except ValidationError Options :=
  OptionsBuilder.parseArguments args >>= OptionsBuilder.build

end Leanfmt
