import Lean
import Leanfmt.FormatError
import Leanfmt.Printer
import Leanfmt.Applicative
import Leanfmt.AST.Type
import Leanfmt.AST.Expr

namespace Leanfmt.AST.Command

open Lean (Syntax)

structure Example where
  private mk ::
  private type : TypeSyntax
  private value : Expr
  deriving Inhabited

open Combinator Leanfmt Leanfmt.Applicative Leanfmt.Formattable in
instance : Formattable Example where
  format ex := do
    text "example : "
    format ex.type
    text " := "
    format ex.value

private partial def findTypeSpec (stx : Syntax) : Option TypeSyntax :=
  match stx with
  | .node _ `Lean.Parser.Term.typeSpec #[_, typeSyntax] =>
    (TypeSyntax.fromSyntax typeSyntax).toOption
  | .node _ _ children =>
    children.foldl (fun acc child => acc <|> findTypeSpec child) none
  | _ => none

private def extractType (optDeclSig : Syntax) : Option TypeSyntax :=
  match optDeclSig with
  | .node _ `Lean.Parser.Command.optDeclSig _ => findTypeSpec optDeclSig
  | _ => none

private def extractValue (body : Syntax) : Option Expr :=
  match body with
  | .node _ `Lean.Parser.Command.declValSimple #[_, valueSyntax, _, _] =>
    (Expr.fromSyntax valueSyntax).toOption
  | .node _ `Lean.Parser.Command.declValSimple #[_, valueSyntax] =>
    (Expr.fromSyntax valueSyntax).toOption
  | _ => none

def Example.fromSyntax (stx : Syntax) : Except FormatError Example := do
  let (optDeclSig, body) ← match stx with
    | .node _ `Lean.Parser.Command.declaration #[_, innerCmd] =>
      match innerCmd with
      | .node _ `Lean.Parser.Command.example #[_, declSig, declVal] => pure (declSig, declVal)
      | .node _ `Lean.Parser.Command.example #[_, declSig, declVal, _] => pure (declSig, declVal)
      | _ =>
        throw (FormatError.unimplemented s!"example: expected example syntax inside declaration but got {innerCmd.getKind}")
    | .node _ `Lean.Parser.Command.example #[_, declSig, declVal] => pure (declSig, declVal)
    | .node _ `Lean.Parser.Command.example #[_, declSig, declVal, _] => pure (declSig, declVal)
    | _ => throw (FormatError.unimplemented s!"example: expected example syntax but got {stx.getKind}")
  let typeOpt := extractType optDeclSig
  let valueOpt := extractValue body
  match typeOpt, valueOpt with
  | some type, some value => return { type := type, value := value }
  | none, some _ => throw (FormatError.unimplemented s!"example: unable to parse type from {optDeclSig.getKind}")
  | some _, none => throw (FormatError.unimplemented s!"example: unable to parse value from {body.getKind}")
  | _, _ => throw (FormatError.unimplemented s!"example: unable to parse type or value")

end Leanfmt.AST.Command
