import Lean
import Leanfmt.FormatError
import Leanfmt.Printer
import Leanfmt.Applicative
import Leanfmt.AST.Command.Definition
import Leanfmt.AST.Command.Check
import Leanfmt.AST.Command.Eval
import Leanfmt.AST.Command.Example

namespace Leanfmt.AST

open Command in
private inductive CommandImpl where
  | definition (defn : Definition) : CommandImpl
  | check (chk : Check) : CommandImpl
  | eval (ev : Eval) : CommandImpl
  | example (ex : Example) : CommandImpl
  deriving Inhabited

structure Command where
  private mk ::
  private val : CommandImpl
  deriving Inhabited

open Combinator Leanfmt Leanfmt.Applicative Leanfmt.Formattable in
instance : Formattable Command where
  format : Command → Printer Unit
    | ⟨.definition defn⟩ => format defn
    | ⟨.check chk⟩ => format chk
    | ⟨.eval ev⟩ => format ev
    | ⟨.example ex⟩ => format ex

open Lean (Syntax) in
open Command in
def Command.fromSyntax (stx : Syntax) : Except FormatError Command := do
  if isValidCommandSyntax stx then
    (Example.fromSyntax stx |>.map (⟨.example ·⟩)) <|>
    (Definition.fromSyntax stx |>.map (⟨.definition ·⟩)) <|>
    (Check.fromSyntax stx |>.map (⟨.check ·⟩)) <|>
    (Eval.fromSyntax stx |>.map (⟨.eval ·⟩)) <|>
    .error (FormatError.unimplemented s!"command: {stx.getKind}")
  else
    .error (FormatError.unimplemented s!"command: expected command syntax but got {stx.getKind}")
where
  isValidCommandSyntax : Syntax → Bool
    | .node _ kind _ =>
      kind != `null &&
      kind != `Lean.Parser.Command.eoi
    | _ => false

end Leanfmt.AST
