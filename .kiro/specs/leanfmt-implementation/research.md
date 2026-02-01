# Research & Design Decisions Template

---
**Purpose**: Capture discovery findings, architectural investigations, and rationale that inform the technical design.

**Usage**:
- Log research activities and outcomes during the discovery phase.
- Document design decision trade-offs that are too detailed for `design.md`.
- Provide references and evidence for future audits or reuse.
---

## Summary
- **Feature**: leanfmt-implementation
- **Discovery Scope**: Complex Integration
- **Key Findings**:
  - Lean の `Lean.Parser.Module` は `parseHeader` と `parseCommand` を提供しており、ネイティブ構文解析を段階的に実行できるため、CLI からの解析入口はこの API に合わせて設計するのが妥当。
  - `IO.FS.readFile` と `IO.FS.writeFile` が標準のファイル入出力 API であり、ファイル/標準入力の取り扱いは `IO` 例外を境界で捕捉する設計が必要。
  - `lean-toolchain` は Elan のツールチェーン選択に影響し、`lake exe` が実行時ビルドと実行の標準経路になるため、CLI 仕様は Lake 実行と相性の良い終了コードと標準出力/標準エラーの分離を前提にする。

## Research Log
Document notable investigation steps and their outcomes. Group entries by topic for readability.

### Lean 4 解析 API の確認
- **Context**: CLI が Lean のネイティブパーサを利用して AST を生成するための公式 API を確認する必要があった。
- **Sources Consulted**: https://lean-lang.org/doc/api/Lean/Parser/Module.html
- **Findings**:
  - `parseHeader` が入力コンテキストからヘッダ解析と `ModuleParserState` を返す。
  - `parseCommand` が `Syntax` と状態・メッセージログを返す。
  - `isTerminalCommand` を使って終端判定を行う設計が想定されている。
- **Implications**: 解析は `Leanfmt.AST.Module.parse` で Lean Parser API を直接呼び出し、終端判定とエラーメッセージを CLI に集約する境界設計を採用する。

### ファイル/標準入出力 API
- **Context**: 入力ソース（ファイル/標準入力）と出力先（stdout/in-place）の両方を扱うため、標準 IO API を確認する必要があった。
- **Sources Consulted**: https://lean-lang.org/doc/api/Init/System/IO.html
- **Findings**:
  - `IO.FS.readFile` と `IO.FS.writeFile` が標準ファイル操作 API として提供されている。
  - IO は例外を伴うため、CLI 層で例外捕捉とエラー整形が必要になる。
- **Implications**: CLI 境界で IO 例外を捕捉し、ユーザー向けの診断メッセージと終了コードを一貫して返す。

### ツールチェーンと実行経路
- **Context**: Lean 4 バージョン固定と実行経路が設計に与える影響（再現性、CI 実行）を確認する必要があった。
- **Sources Consulted**:
  - https://lean-lang.org/doc/reference/latest/Build-Tools-and-Distribution/Managing-Toolchains-with-Elan/
  - https://lean-lang.org/doc/reference/latest/Build-Tools-and-Distribution/Lake/
  - https://github.com/leanprover/lake
- **Findings**:
  - `lean-toolchain` ファイルが Elan のツールチェーン選択に利用され、プロジェクト単位で Lean バージョンを固定できる。
  - `lake exe` は実行対象をビルドしてから実行する標準コマンドであり、CLI 実行の主要経路となる。
  - Lake は Lean 4 と一体で配布され、Lean 4 の標準ビルド/実行基盤である。
- **Implications**: 設計では Lean 4 v4.22.0（`lean-toolchain`）固定を前提とし、`lake exe leanfmt` 実行時の標準出力/標準エラーと終了コードの明確化を必須要件として扱う。

## Architecture Pattern Evaluation
List candidate patterns or approaches that were considered. Use the table format where helpful.

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| パイプライン（解析→AST→整形→出力） | 各段階を直列に分離 | 責務分離が明確、既存構成と一致 | 段階間のエラー伝播設計が必要 | 既存 `Leanfmt` 構造と合致 |
| ヘキサゴナル | コアにポート/アダプタを明示 | 入出力境界が明確 | 小規模に対して過剰設計 | 将来の拡張性は高い |

## Design Decisions
Record major decisions that influence `design.md`. Focus on choices with significant trade-offs.

### Decision: Lean ネイティブパーサ API を直接使用
- **Context**: 構文解析の信頼性と Lean 4 互換性を最優先する必要がある。
- **Alternatives Considered**:
  1. 外部パーサライブラリを導入 — 追加依存と互換性リスク
  2. Lean.Parser.Module を直接使用 — 公式 API で互換性が高い
- **Selected Approach**: `Lean.Parser.Module.parseHeader/parseCommand` を用い、`Leanfmt.AST.Module.parse` に集約する。
- **Rationale**: Lean 4 の標準 API に合わせることで構文互換性と将来の更新追従を確保できる。
- **Trade-offs**: Lean の API 変更の影響を受けやすい。
- **Follow-up**: Lean バージョン更新時に Parser API の互換性確認を行う。

### Decision: CLI 層で IO 例外を捕捉し診断を統一
- **Context**: 入力/出力エラーはユーザーに明確な診断が必要。
- **Alternatives Considered**:
  1. 各関数で例外を個別処理
  2. CLI 境界で一括処理
- **Selected Approach**: CLI が IO 例外を捕捉し、モードごとに統一されたメッセージと終了コードを返す。
- **Rationale**: 例外処理の散逸を防ぎ、エラー体験を統一できる。
- **Trade-offs**: CLI の責務が増える。
- **Follow-up**: 例外種別ごとのメッセージ標準化を設計で明記する。

### Decision: フォーマッタは決定的・冪等な出力を契約化
- **Context**: CI とチーム運用で整形結果の再現性が必須。
- **Alternatives Considered**:
  1. 状態依存の整形（柔軟だが不安定）
  2. 決定的な AST→文字列変換（安定）
- **Selected Approach**: `Formattable` と `runFormatter` により AST から決定的な出力を生成する契約を定義。
- **Rationale**: 再実行時の一致（冪等性）と CI 判定が容易になる。
- **Trade-offs**: レイアウト拡張時に規則設計が必要。
- **Follow-up**: 冪等性テストをゴールデンテストに統合する。

## Risks & Mitigations
- 解析対象の文法カバレッジ不足 — 解析対象を段階的に拡張し、未対応は `FormatError` で明示。
- 大規模ファイルでのパフォーマンス低下 — CLI による逐次処理を維持しつつ、将来の並列化余地を設計に記載。
- エラー診断の不統一 — エラー分類と終了コードの対応表を設計で固定。

## References
Provide canonical links and citations (official docs, standards, ADRs, internal guidelines).
- https://lean-lang.org/doc/api/Lean/Parser/Module.html — Lean Parser API
- https://lean-lang.org/doc/api/Init/System/IO.html — IO API (readFile/writeFile)
- https://lean-lang.org/doc/reference/latest/Build-Tools-and-Distribution/Managing-Toolchains-with-Elan/ — Elan toolchain management
- https://lean-lang.org/doc/reference/latest/Build-Tools-and-Distribution/Lake/ — Lake build/run reference
- https://github.com/leanprover/lake — Lake distribution and usage notes
