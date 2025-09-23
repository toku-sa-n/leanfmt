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

open Lean (Syntax) in
def Command.fromSyntax (stx : Syntax) : Except FormatError Command := do
  match stx with
  | .node _ `Lean.Parser.Command.declaration #[_, defn] =>
    parseDefinition defn
  | _ => throw (FormatError.unimplemented s!"command: {stx.getKind}")
where
  parseDefinition (stx : Syntax) : Except FormatError Command := do
    match stx with
    | .node _ `Lean.Parser.Command.definition #[_, declId, optDeclSig, body, _] =>
      match declId with
      | .node _ `Lean.Parser.Command.declId #[id, _] =>
        return ⟨.definition
          (Identifier.fromName id.getId)
          (extractType optDeclSig)
          (extractValue body)⟩
      | _ => throw (FormatError.unimplemented s!"definition declId: {declId.getKind}")
    | _ => throw (FormatError.unimplemented s!"declaration kind: {stx.getKind}")

  extractType (optDeclSig : Syntax) : Option TypeSyntax :=
    match optDeclSig with
    | .node _ `Lean.Parser.Command.optDeclSig #[_, .node _ `null #[.node _ `Lean.Parser.Term.typeSpec #[_, typeSyntax]]] =>
      (TypeSyntax.fromSyntax typeSyntax).toOption
    | _ => none

  extractValue (body : Syntax) : Option Expr :=
    match body with
    | .node _ `Lean.Parser.Command.declValSimple #[_, valueSyntax, _, _] =>
      (Expr.fromSyntax valueSyntax).toOption
    | _ => none

end Leanfmt.AST