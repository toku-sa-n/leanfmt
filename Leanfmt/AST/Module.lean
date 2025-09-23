import Lean
import Lean.Parser
import Leanfmt.FormatError
import Leanfmt.Printer
import Leanfmt.AST.Command

namespace Leanfmt.AST

structure Module where
  private mk ::
  private commands : Array Command
  deriving Inhabited

open Combinator Leanfmt.Formattable in
instance : Formattable Module where
  format m := sepByBlankLine (m.commands.map format)


open Lean (initSearchPath findSysroot importModules Syntax nullKind) in
open Lean.Parser (mkInputContext parseHeader parseCommand isTerminalCommand) in
partial def Module.parse (source : String) (fileName : String) : IO Module := do
    let inputCtx := mkInputContext source fileName
    let (_, parserState, messages) ← parseHeader inputCtx
    initSearchPath (← findSysroot)
    let env ← importModules (imports := #[{ module := `Init }]) (opts := { }) (loadExts := true)
    let pmctx := { env := env, options := { } }
    let mut commands := #[]
    let mut state := parserState
    let mut msgs := messages
    repeat
      let (stx, state', msgs') := parseCommand inputCtx pmctx state msgs
      if isTerminalCommand stx then break
      state := state'
      msgs := msgs'
      commands := commands.push stx
    parseBody (Syntax.node default nullKind commands)
      |> IO.ofExcept
      |>.map (fun commands => { commands := commands })
where
  parseBody (stx : Lean.Syntax) : Except FormatError (Array Command) := do
    match stx with
    | .node _ _ args =>
      (args.filter fun arg =>
        arg.getKind != `Lean.Parser.Command.eoi && arg.getKind != `null).mapM Command.fromSyntax
    | _ => return #[]

end Leanfmt.AST
