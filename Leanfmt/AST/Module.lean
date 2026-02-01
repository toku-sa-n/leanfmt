import Lean
import Std
import Lean.Parser
import Leanfmt.FormatConfig
import Leanfmt.FormatError
import Leanfmt.Printer

namespace Leanfmt.AST

structure Header where
  private mk ::
  private prelude : Bool
  private imports : Array Lean.Name
  deriving Inhabited

structure Module where
  private mk ::
  private fileName : String
  private fileMap : Lean.FileMap
  private header : Header
  private commands : Array Lean.Command
  deriving Inhabited

private def Header.empty : Header :=
  { prelude := false, imports := #[] }

private partial def hasPrelude (stx : Lean.Syntax) : Bool :=
  match stx with
  | .node _ `Lean.Parser.Module.prelude _ => true
  | .node _ _ args => args.any hasPrelude
  | _ => false

private partial def extractImportName (stx : Lean.Syntax) : Option Lean.Name :=
  match stx with
  | .ident _ _ name _ => some name
  | .node _ _ args =>
      args.foldl (fun acc arg => acc <|> extractImportName arg) none
  | _ => none

private partial def collectImports (stx : Lean.Syntax) (acc : Array Lean.Name) : Array Lean.Name :=
  match stx with
  | .node _ `Lean.Parser.Module.import _ =>
      match extractImportName stx with
      | some name => acc.push name
      | none => acc
  | .node _ _ args =>
      args.foldl (fun acc arg => collectImports arg acc) acc
  | _ => acc

private def Header.fromSyntax (stx : Lean.TSyntax `Lean.Parser.Module.header) : Header :=
  let raw := stx.raw
  { prelude := hasPrelude raw, imports := collectImports raw #[] }

private def messageLogToString (log : Lean.MessageLog) : IO String := do
  let errors := log.toList.filter (fun msg =>
    match msg.severity with
    | .error => true
    | _ => false)
  let rendered ← errors.mapM (fun msg => msg.toString)
  return String.intercalate "\n" rendered

private def mkCoreContext (fileName : String) (fileMap : Lean.FileMap) : Lean.Core.Context :=
  let options := ({} : Lean.Options)
  {
    fileName := fileName,
    fileMap := fileMap,
    options := options,
    currRecDepth := 0,
    maxRecDepth := 1000,
    ref := Lean.Syntax.missing,
    currNamespace := Lean.Name.anonymous,
    openDecls := [],
    initHeartbeats := 0,
    maxHeartbeats := Lean.Core.getMaxHeartbeats options,
    currMacroScope := Lean.firstFrontendMacroScope,
    diag := false,
    cancelTk? := none,
    suppressElabErrors := false,
    inheritedTraceOptions := ∅
  }

private def mkCoreState (env : Lean.Environment) : Lean.Core.State :=
  {
    env := env,
    nextMacroScope := Lean.firstFrontendMacroScope + 1,
    ngen := {},
    auxDeclNGen := {},
    traceState := {},
    cache := {},
    messages := {},
    infoState := {},
    snapshotTasks := #[]
  }

private def prettyCommand
    (cmd : Lean.Command)
    (ctx : Lean.Core.Context)
    (st : Lean.Core.State)
    (width : Nat) : IO String := do
  let (fmt, _) ← Lean.Core.CoreM.toIO (Lean.PrettyPrinter.ppCommand cmd) ctx st
  return Std.Format.pretty fmt width

open Combinator in
instance : Formattable Module where
  format m := do
    let cfg ← Leanfmt.getFormatConfig
    let width := Nat.max 10 (Leanfmt.FormatConfig.getMaxLineLength cfg)
    let env ← liftM <| do
      Lean.initSearchPath (← Lean.findSysroot)
      Lean.importModules (imports := #[{ module := `Lean }, { module := `Std }]) (opts := {}) (loadExts := true)
    let ctx := mkCoreContext m.fileName m.fileMap
    let st := mkCoreState env

    let hasHeader := m.header.prelude || !m.header.imports.isEmpty
    if m.header.prelude then
      text "prelude"
      newline
    for imp in m.header.imports do
      text s!"import {imp.toString}"
      newline
    if hasHeader && !m.commands.isEmpty then
      newline

    for i in [0:m.commands.size] do
      let cmd := m.commands[i]!
      let formatted ← liftM <| prettyCommand cmd ctx st width
      text formatted
      if i + 1 < m.commands.size then
        newline

open Lean (initSearchPath findSysroot importModules Syntax) in
open Lean.Parser (mkInputContext parseHeader parseCommand isTerminalCommand) in
partial def Module.parse (source : String) (fileName : String) : IO Module := do
  let inputCtx := mkInputContext source fileName
  let (headerSyntax, parserState, messages) ← parseHeader inputCtx
  if messages.hasErrors then
    let detail ← messageLogToString messages
    throw <| IO.userError (toString (FormatError.parseError detail))

  initSearchPath (← findSysroot)
  let env ← importModules (imports := #[{ module := `Lean }, { module := `Std }]) (opts := { }) (loadExts := true)
  let pmctx := { env := env, options := { } }
  let mut commands : Array Lean.Command := #[]
  let mut state := parserState
  let mut msgs := messages
  repeat
    let (stx, state', msgs') := parseCommand inputCtx pmctx state msgs
    if isTerminalCommand stx then break
    if msgs'.hasErrors then
      let detail ← messageLogToString msgs'
      throw <| IO.userError (toString (FormatError.parseError detail))
    state := state'
    msgs := msgs'
    commands := commands.push (Lean.TSyntax.mk stx)

  let header := Header.fromSyntax headerSyntax
  return { fileName := fileName, fileMap := inputCtx.fileMap, header := header, commands := commands }

end Leanfmt.AST
