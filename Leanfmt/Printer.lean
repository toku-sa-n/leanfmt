import Lean
import Leanfmt.FormatConfig

namespace Leanfmt

private structure PrinterState where
  builder : String
  column : Nat
  config : FormatConfig
  deriving Inhabited

abbrev Printer := StateT PrinterState IO

class Formattable (α : Type) where
  format : α → Printer Unit

def getFormatConfig : Printer FormatConfig := do
  return (← get).config

def runFormatter {α : Type} [Formattable α] (a : α) (config : FormatConfig := default) : IO String :=
  StateT.run (Formattable.format a) { (default : PrinterState) with config }
    |>.map fun (_, st) => st.builder.dropRightWhile (· == '\n') ++ "\n"

namespace Combinator

def text (s : String) : Printer Unit := do
  if s.isEmpty then
    return
  modify fun st => { st with builder := st.builder ++ s, column := st.column + s.length }

def newline : Printer Unit := do
  modify fun st => { st with builder := st.builder ++ "\n", column := 0 }

def sepByBlankLine (items : Array (Printer Unit)) : Printer Unit := do
  if items.isEmpty then
    pure ()
  else if items.size == 1 then
    items[0]!
  else
    items[0]!
    for i in [1:items.size] do
      newline
      items[i]!

def space : Printer Unit := text " "

def parens (m : Printer Unit) : Printer Unit := do
  text "("
  m
  text ")"


end Combinator

end Leanfmt
