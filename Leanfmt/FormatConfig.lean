namespace Leanfmt

structure FormatConfig where
  private mk ::
  private indentSize : Nat := 2
  private maxLineLength : Nat := 100
  deriving Repr, Inhabited

def FormatConfig.getIndentSize (cfg : FormatConfig) : Nat := cfg.indentSize
def FormatConfig.getMaxLineLength (cfg : FormatConfig) : Nat := cfg.maxLineLength

end Leanfmt
