import Lean
import Leanfmt.FormatError
import Leanfmt.Printer
import Leanfmt.Applicative
import Leanfmt.AST.Identifier
import Leanfmt.AST.Type
import Leanfmt.AST.Expr

namespace Leanfmt.AST.Command

structure Definition where
  private mk ::
  private name : Identifier
  private type : Option TypeSyntax
  private value : Option Expr
  deriving Inhabited

open Combinator Leanfmt Leanfmt.Applicative Leanfmt.Formattable in
instance : Formattable Definition where
  format defn := do
    text "def "
    format defn.name
    whenSome defn.type fun t => do
      text " : "
      format t
    whenSome defn.value fun expr => do
      text " := "
      format expr

open Lean (Syntax) in
private partial def findTypeSpec (stx : Syntax) : Option TypeSyntax :=
  match stx with
  | .node _ `Lean.Parser.Term.typeSpec #[_, typeSyntax] =>
    (TypeSyntax.fromSyntax typeSyntax).toOption
  | .node _ _ children =>
    children.foldl (fun acc child => acc <|> findTypeSpec child) none
  | _ => none

open Lean (Syntax) in
private def extractType (optDeclSig : Syntax) : Option TypeSyntax :=
  if let .node _ `Lean.Parser.Command.optDeclSig _ := optDeclSig then
    findTypeSpec optDeclSig
  else
    none

open Lean (Syntax) in
private def extractValue (body : Syntax) : Option Expr :=
  match body with
  | .node _ `Lean.Parser.Command.declValSimple #[_, valueSyntax, _, _]
  | .node _ `Lean.Parser.Command.declValSimple #[_, valueSyntax] =>
    (Expr.fromSyntax valueSyntax).toOption
  | _ => none

open Lean (Syntax) in
def Definition.fromSyntax (stx : Syntax) : Except FormatError Definition := do
  match stx with
  | .node _ `Lean.Parser.Command.declaration #[_, innerCmd] =>
    Definition.fromSyntax innerCmd
  | .node _ `Lean.Parser.Command.definition #[_, declId, optDeclSig, body, _] =>
    let .node _ `Lean.Parser.Command.declId #[id, _] := declId
      | throw (FormatError.unimplemented s!"definition: unexpected declId structure")
    return {
      name := Identifier.fromName id.getId
      type := extractType optDeclSig
      value := extractValue body
    }
  | .node _ `Lean.Parser.Command.declaration _ =>
    throw (FormatError.unexpectedASTStructure s!"definition: malformed declaration wrapper {stx}")
  | _ =>
    throw (FormatError.unimplemented s!"definition: expected definition syntax but got {stx.getKind}")

end Leanfmt.AST.Command
