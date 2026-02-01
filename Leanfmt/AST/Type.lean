import Lean
import Leanfmt.FormatError
import Leanfmt.Printer

namespace Leanfmt.AST
mutual
  private inductive TypeSyntaxImpl where
    | simple (name : String) : TypeSyntaxImpl
    | arrow (left : TypeSyntax) (right : TypeSyntax) : TypeSyntaxImpl
    | app (func : TypeSyntax) (arg : TypeSyntax) : TypeSyntaxImpl
    deriving Inhabited
  structure TypeSyntax where private mk ::
    private val : TypeSyntaxImpl
    deriving Inhabited
end
open Combinator (text parens space) in
instance : Formattable TypeSyntax where format := go
where go
    | ⟨.simple name⟩ => text name
    | ⟨.arrow left right⟩ => do
      match left.val with
      | .arrow _ _ =>
        parens (go left)
      | _ =>
        go left
      text " → "
      go right
    | ⟨.app func arg⟩ => do
      go func
      space
      match arg.val with
      | .simple _ =>
        go arg
      | _ =>
        parens (go arg)
open Lean (Syntax) in
def TypeSyntax.fromSyntax (stx : Syntax) : Except FormatError TypeSyntax := do
  match stx with
  | .ident _ _ name _ =>
    return ⟨.simple name.toString⟩
  | .atom _ val =>
    return ⟨.simple val⟩
  | .node _ `Lean.Parser.Term.arrow #[left, _, right] =>
    do
      return ⟨.arrow (← TypeSyntax.fromSyntax left) (← TypeSyntax.fromSyntax right)⟩
  | .node _ `Lean.Parser.Term.app #[func, arg] =>
    do
      return ⟨.app (← TypeSyntax.fromSyntax func) (← TypeSyntax.fromSyntax arg)⟩
  | .node _ `Lean.Parser.Term.paren #[_, inner, _] =>
    TypeSyntax.fromSyntax inner
  | .node _ _ _ =>
    return ⟨.simple s! "{stx}"⟩
  | .missing =>
    throw (FormatError.unexpectedASTStructure "missing type syntax node")
end Leanfmt.AST
