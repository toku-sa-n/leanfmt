namespace Leanfmt

structure FormatConfig where
  private mk ::
  private indentSize : Nat := 2
  private maxLineLength : Nat := 100
  deriving Repr

def defaultFormatConfig : FormatConfig :=
  FormatConfig.mk 2 100

instance : Inhabited FormatConfig where
  default := defaultFormatConfig

def FormatConfig.getIndentSize (cfg : FormatConfig) : Nat := cfg.indentSize
def FormatConfig.getMaxLineLength (cfg : FormatConfig) : Nat := cfg.maxLineLength

end Leanfmt
