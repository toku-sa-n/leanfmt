namespace Leanfmt.CLI.Options

inductive ValidationError
  | conflictingModes : ValidationError
  | missingFiles : ValidationError
  | unknownOption : String → ValidationError
  deriving Inhabited

instance : ToString ValidationError where
  toString
    | .conflictingModes => "Error: Cannot use --check and --in-place together"
    | .missingFiles => "Error: --check and --in-place require file arguments"
    | .unknownOption opt => s!"Unknown option: {opt}\nUse --help for usage information"

end Leanfmt.CLI.Options