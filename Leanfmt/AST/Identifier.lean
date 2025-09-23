import Lean
import Leanfmt.Printer

namespace Leanfmt.AST

open Lean (Name)

structure Identifier where
  fromName ::
  private name : Name
  deriving Inhabited

open Combinator in
instance : Formattable Identifier where
  format id := text id.name.toString


end Leanfmt.AST