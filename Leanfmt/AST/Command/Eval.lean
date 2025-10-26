import Lean
import Leanfmt.FormatError
import Leanfmt.Printer
import Leanfmt.Applicative
import Leanfmt.AST.Expr

namespace Leanfmt.AST.Command

structure Eval where
  private mk ::
  private expr : Expr
  deriving Inhabited

open Combinator Leanfmt Leanfmt.Applicative Leanfmt.Formattable in
instance : Formattable Eval where
  format ev := do
    text "#eval "
    format ev.expr

open Lean (Syntax) in
def Eval.fromSyntax (stx : Syntax) : Except FormatError Eval := do
  match stx with
  | .node _ `Lean.Parser.Command.eval #[_, expr] =>
    return { expr := ← Expr.fromSyntax expr }
  | _ => throw (FormatError.unimplemented s!"eval: expected #eval syntax but got {stx.getKind}")

end Leanfmt.AST.Command
