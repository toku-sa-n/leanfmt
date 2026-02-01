namespace Leanfmt.CLI.Options
inductive ValidationError
  | conflictingModes : ValidationError
  | missingFiles : ValidationError
  | multipleStdin : ValidationError
  | stdinInPlace : ValidationError
  | unknownOption : String → ValidationError
  deriving Inhabited
instance : ToString ValidationError where
  toString
    | .conflictingModes => "Error: Cannot use --check and --in-place together"
    | .missingFiles => "Error: --in-place requires file arguments"
    | .multipleStdin => "Error: '-' can only be specified once"
    | .stdinInPlace => "Error: Cannot use '-' with --in-place"
    | .unknownOption opt => s! "Unknown option: {opt}\nUse --help for usage information"
end Leanfmt.CLI.Options
