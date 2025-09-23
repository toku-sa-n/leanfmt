import Lean
import Leanfmt.FormatError
import Leanfmt.Printer
import Leanfmt.Applicative
import Leanfmt.AST.Identifier
import Leanfmt.AST.Type
import Leanfmt.AST.Expr

namespace Leanfmt.AST

private inductive CommandImpl where
  | definition (name : Identifier) (type : Option TypeSyntax) (value : Option Expr) : CommandImpl
  | check (expr : Expr) : CommandImpl
  | eval (expr : Expr) : CommandImpl
  | example (type : TypeSyntax) (value : Expr) : CommandImpl
  deriving Inhabited

structure Command where
  private mk ::
  private val : CommandImpl
  deriving Inhabited

open Combinator Leanfmt Leanfmt.Applicative Leanfmt.Formattable in
instance : Formattable Command where
  format : Command → Printer Unit
    | ⟨.definition name type value⟩ => do
      text "def "
      format name
      whenSome type fun t => do
        text " : "
        format t
      whenSome value fun expr => do
        text " := "
        format expr
    | ⟨.check expr⟩ => do
      text "#check "
      format expr
    | ⟨.eval expr⟩ => do
      text "#eval "
      format expr
    | ⟨.example type value⟩ => do
      text "example : "
      format type
      text " := "
      format value

open Lean (Syntax)

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

private def parseExample (optDeclSig : Syntax) (body : Syntax) : Except FormatError Command := do
  let typeOpt := extractType optDeclSig
  let valueOpt := extractValue body
  match typeOpt, valueOpt with
  | some type, some value => return ⟨.example type value⟩
  | none, some _ => throw (FormatError.unimplemented s!"example: unable to parse type from {optDeclSig.getKind}")
  | some _, none => throw (FormatError.unimplemented s!"example: unable to parse value from {body.getKind}")
  | _, _ => throw (FormatError.unimplemented s!"example: unable to parse type or value")

private def parseDeclaration (stx : Syntax) : Except FormatError Command := do
  match stx with
  | .node _ `Lean.Parser.Command.definition #[_, declId, optDeclSig, body, _] =>
    match declId with
    | .node _ `Lean.Parser.Command.declId #[id, _] =>
      return ⟨.definition
        (Identifier.fromName id.getId)
        (extractType optDeclSig)
        (extractValue body)⟩
    | _ => throw (FormatError.unimplemented s!"definition declId: {declId.getKind}")
  | .node _ `Lean.Parser.Command.example #[_, declSig, declVal] =>
    parseExample declSig declVal
  | .node _ `Lean.Parser.Command.example #[_, declSig, declVal, _] =>
    parseExample declSig declVal
  | _ => throw (FormatError.unimplemented s!"declaration kind: {stx.getKind}")

def Command.fromSyntax (stx : Syntax) : Except FormatError Command := do
  match stx with
  | .node _ `Lean.Parser.Command.declaration #[_, defn] =>
    parseDeclaration defn
  | .node _ `Lean.Parser.Command.check #[_, expr] =>
    return ⟨.check (← Expr.fromSyntax expr)⟩
  | .node _ `Lean.Parser.Command.eval #[_, expr] =>
    return ⟨.eval (← Expr.fromSyntax expr)⟩
  | _ => throw (FormatError.unimplemented s!"command: {stx.getKind}")

end Leanfmt.AST