import Lean
import Leanfmt.FormatError
import Leanfmt.Printer
import Leanfmt.Applicative
import Leanfmt.AST.Expr

namespace Leanfmt.AST.Command

structure Check where
  private mk ::
  private expr : Expr
  deriving Inhabited

open Combinator Leanfmt Leanfmt.Applicative Leanfmt.Formattable in
instance : Formattable Check where
  format chk := do
    text "#check "
    format chk.expr

open Lean (Syntax) in
def Check.fromSyntax (stx : Syntax) : Except FormatError Check := do
  match stx with
  | .node _ `Lean.Parser.Command.check #[_, expr] =>
    return { expr := ← Expr.fromSyntax expr }
  | _ => throw (FormatError.unimplemented s!"check: expected #check syntax but got {stx.getKind}")

end Leanfmt.AST.Command
