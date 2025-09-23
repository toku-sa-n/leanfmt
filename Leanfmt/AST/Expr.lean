import Lean
import Leanfmt.FormatError
import Leanfmt.Printer
import Leanfmt.AST.Identifier

namespace Leanfmt.AST

inductive Expr where
  | ident (id : Identifier) : Expr
  | num (value : String) : Expr
  | str (value : String) : Expr
  | app (fn : Expr) (args : List Expr) : Expr
  deriving Inhabited

open Formattable Combinator in
instance : Formattable Expr where
  format := go
where
  go : Expr → Printer Unit
    | .ident id => format id
    | .num value => text value
    | .str value => text value
    | .app fn args => do
      go fn
      for arg in args do
        text " "
        go arg

open Lean (Syntax Name) in

partial def Expr.fromSyntax (stx : Syntax) : Except FormatError Expr := do
  match stx with
  | Syntax.ident _ _ name _ =>
    return Expr.ident (Identifier.fromName name)
  | Syntax.atom _ val =>
    return Expr.ident (Identifier.fromName (Name.mkSimple val))
  | Syntax.node _ `num #[Syntax.atom _ val] =>
    return Expr.num val
  | Syntax.node _ `Lean.Parser.Term.num #[Syntax.atom _ val] =>
    return Expr.num val
  | Syntax.node _ `Lean.Parser.Term.str #[Syntax.atom _ val] =>
    return Expr.str val
  | Syntax.node _ `Lean.Parser.Term.app #[fn, Syntax.node _ `null args] =>
    let fn ← Expr.fromSyntax fn
    let mut parsedArgs : List Expr := []
    for arg in args do
      let parsed ← Expr.fromSyntax arg
      parsedArgs := parsedArgs ++ [parsed]
    return Expr.app fn parsedArgs
  | _ =>
    throw (FormatError.unimplemented s!"expression: {stx.getKind}")

end Leanfmt.AST