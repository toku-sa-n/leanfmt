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
  | theorem (name : Identifier) (type : Option Expr) (value : Option Expr) : CommandImpl
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
  format := formatCommand
  where
    formatDefinition name type value := do
      text "def"
      text " "
      format name
      whenSome type fun t => do
        text " : "
        format t
      whenSome value fun expr => do
        text " := "
        format expr
    formatTheorem name type value := do
      text "theorem"
      text " "
      format name
      whenSome type fun t => do
        text " : "
        format t
      whenSome value fun expr => do
        text " := "
        format expr
    formatCommand : Command → Printer Unit
      | ⟨.definition name type value⟩ =>
        formatDefinition name type value
      | ⟨.theorem name type value⟩ =>
        formatTheorem name type value
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
  | .node _ `Lean.Parser.Command.declSig _ => findTypeSpec optDeclSig
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

private def parseDefinition
    (declId : Syntax)
    (optDeclSig : Syntax)
    (body : Syntax)
    : Except FormatError Command := do
  match declId with
  | .node _ `Lean.Parser.Command.declId #[id, _] =>
    return ⟨.definition
      (Identifier.fromName id.getId)
      (extractType optDeclSig)
      (extractValue body)⟩
  | _ => throw (FormatError.unimplemented s!"definition declId: {declId.getKind}")

private def extractTheoremType (optDeclSig : Syntax) : Option Expr :=
  match optDeclSig with
  | .node _ `Lean.Parser.Command.declSig children =>
    findTypeSpecInChildren children
  | .node _ `Lean.Parser.Command.optDeclSig children =>
    findTypeSpecInChildren children
  | _ => none
where
  findTypeSpecInChildren (children : Array Syntax) : Option Expr :=
    children.foldl (fun acc child =>
      acc <|> match child with
      | .node _ `Lean.Parser.Term.typeSpec #[_, typeExpr] =>
        (Expr.fromSyntax typeExpr).toOption
      | _ => none
    ) none

private def parseTheorem
    (declId : Syntax)
    (optDeclSig : Syntax)
    (body : Syntax)
    : Except FormatError Command := do
  match declId with
  | .node _ `Lean.Parser.Command.declId #[id, _] =>
    return ⟨.theorem
      (Identifier.fromName id.getId)
      (extractTheoremType optDeclSig)
      (extractValue body)⟩
  | _ => throw (FormatError.unimplemented s!"theorem declId: {declId.getKind}")

private def parseDeclaration (stx : Syntax) : Except FormatError Command := do
  match stx with
  | .node _ `Lean.Parser.Command.definition #[_, declId, optDeclSig, body, _] =>
    parseDefinition declId optDeclSig body
  | .node _ `Lean.Parser.Command.example #[_, declSig, declVal] =>
    parseExample declSig declVal
  | .node _ `Lean.Parser.Command.example #[_, declSig, declVal, _] =>
    parseExample declSig declVal
  | _ => throw (FormatError.unimplemented s!"declaration kind: {stx.getKind}")

def Command.fromSyntax (stx : Syntax) : Except FormatError Command := do
  match stx with
  | .node _ `Lean.Parser.Command.declaration #[_, .node _ `Lean.Parser.Command.theorem args] =>
    match args with
    | #[_, declId, optDeclSig, body] =>
      parseTheorem declId optDeclSig body
    | #[_, declId, optDeclSig, body, _] =>
      parseTheorem declId optDeclSig body
    | _ => throw (FormatError.unimplemented s!"theorem args: {args.size}")
  | .node _ `Lean.Parser.Command.declaration #[_, defn] =>
    parseDeclaration defn
  | .node _ `Lean.Parser.Command.check #[_, expr] =>
    return ⟨.check (← Expr.fromSyntax expr)⟩
  | .node _ `Lean.Parser.Command.eval #[_, expr] =>
    return ⟨.eval (← Expr.fromSyntax expr)⟩
  | _ => throw (FormatError.unimplemented s!"command: {stx.getKind}")

end Leanfmt.AST