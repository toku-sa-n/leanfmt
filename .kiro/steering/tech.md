# Technology Stack

## Architecture

- Lean 4 のライブラリとして中核ロジックを実装し、CLI から呼び出す構成
- 解析 → AST → 整形出力のパイプラインで処理を分離
- CLI がオプション解釈とモード切り替えを担当

## Core Technologies

- **Language**: Lean 4（leanprover/lean4:v4.22.0）
- **Build/Package**: Lake
- **Runtime**: Lean 4 ランタイム / Lake による実行バイナリ

## Key Libraries

- Lean 標準ライブラリ（`Lean`）
- Lean の構文解析・シンタックス機構

## Development Standards

### Type Safety

- Lean の型システムを活用し `structure` / `inductive` でデータモデルを定義
- `private` フィールドで不変条件を保護

### Code Quality

- ルート直下の Lean ファイルは `Main.lean` / `Leanfmt.lean` のみを許可
- namespace はディレクトリ構成と一致させる

### Testing

- `test/cases/**/In.lean` と `Out.lean` のゴールデンテスト
- 出力一致 + idempotency（Out.lean 再整形一致）を検証
- `scripts/run-tests.sh` で並列実行、`scripts/validate-test-structure.sh` で構成検証

## Development Environment

### Required Tools

- Lean 4 toolchain（leanprover/lean4:v4.22.0）
- Lake
- Bash（テスト/検証スクリプト用）
- 任意: `parallel`, `colordiff`, `act`（pre-commit）

### Common Commands

```bash
# Build
lake build leanfmt

# Run CLI
lake exe leanfmt --in-place Main.lean

# Tests
lake exe runtests
# または
scripts/run-tests.sh
```

## Key Technical Decisions

- Lean のネイティブパーサを使って整形の正確性を担保
- CLI は stdout / --check / --in-place の 3 モードを中核に設計
- テストはゴールデン + idempotency でリグレッションを防止

---
updated_at: 2026-02-01
