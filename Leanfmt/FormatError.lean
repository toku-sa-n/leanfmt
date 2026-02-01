namespace Leanfmt

inductive FormatError where
  | unimplemented (feature : String)
  | unexpectedASTStructure (syntaxInfo : String)
  | parseError (detail : String)
  deriving Inhabited, Repr

instance : ToString FormatError where
  toString
    | .unimplemented f => s!"unimplemented: {f}"
    | .unexpectedASTStructure syntaxInfo => s!"unexpected AST structure: {syntaxInfo}"
    | .parseError detail => s!"parse error: {detail}"

end Leanfmt
