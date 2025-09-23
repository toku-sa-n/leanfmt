import Lean
import Leanfmt.FormatError
import Leanfmt.Printer
import Leanfmt.AST.Identifier

namespace Leanfmt.AST

private inductive ExprImpl where
  | ident (id : Identifier) : ExprImpl
  | num (value : String) : ExprImpl
  | str (value : String) : ExprImpl
  deriving Inhabited

structure Expr where
  private mk ::
  private val : ExprImpl
  deriving Inhabited

open Leanfmt.Formattable in
open Combinator (text) in
instance : Formattable Expr where
  format : Expr → Printer Unit
    | ⟨.ident id⟩ => format id
    | ⟨.num value⟩ => text value
    | ⟨.str value⟩ => text value

open Lean (Syntax Name) in
def Expr.fromSyntax (stx : Syntax) : Except FormatError Expr := do
  match stx with
  | .ident _ _ name _ =>
    return ⟨.ident (Identifier.fromName name)⟩
  | .atom _ val =>
    return ⟨.ident (Identifier.fromName (Name.mkSimple val))⟩
  | .node _ `num #[.atom _ val] =>
    return ⟨.num val⟩
  | .node _ `Lean.Parser.Term.num #[.atom _ val] =>
    return ⟨.num val⟩
  | .node _ `Lean.Parser.Term.str #[.atom _ val] =>
    return ⟨.str val⟩
  | _ =>
    throw (FormatError.unimplemented s!"expression: {stx.getKind}")

end Leanfmt.AST