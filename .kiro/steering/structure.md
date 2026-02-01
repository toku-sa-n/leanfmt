# Project Structure

## Organization Philosophy

- Lean モジュールはドメインごとに分割し、ディレクトリと namespace を一致させる
- ルートはエントリポイントと公開モジュールの集約に限定する

## Directory Patterns

### Root Entry Points
**Location**: `/`  
**Purpose**: CLI エントリポイントとライブラリ集約のみを配置  
**Example**: `Main.lean`, `Leanfmt.lean`

### Core Library Modules
**Location**: `/Leanfmt/`  
**Purpose**: フォーマッタの中核ロジック（AST、CLI、設定、デバッグ）  
**Example**: `Leanfmt/AST/Command.lean`, `Leanfmt/CLI.lean`

### CLI Options Submodules
**Location**: `/Leanfmt/CLI/Options/`  
**Purpose**: CLI オプション検証とエラー定義  
**Example**: `Leanfmt/CLI/Options/ValidationError.lean`

### Tests (Golden)
**Location**: `/test/cases/`  
**Purpose**: leaf ディレクトリに `In.lean` / `Out.lean` を置くゴールデンテスト  
**Example**: `test/cases/basic/.../In.lean`, `test/cases/basic/.../Out.lean`

### Scripts
**Location**: `/scripts/`  
**Purpose**: テスト実行・構造検証・pre-commit 補助  
**Example**: `scripts/run-tests.sh`

## Naming Conventions

- **Files**: Lean モジュールは PascalCase、テストは `In.lean` / `Out.lean`
- **Namespaces**: `Leanfmt.*` でディレクトリ構成に合わせる
- **Definitions**: `def` は lowerCamel、`structure`/`inductive` は UpperCamel
- **Scripts**: `kebab-case.sh`

## Import Organization

```lean
import Leanfmt.AST.Module
import Leanfmt.CLI
```

**Path Aliases**:
- なし（Lean のモジュールパスをそのまま使用）

## Code Organization Principles

- AST 定義は `Leanfmt.AST` に集約し、CLI から独立させる
- CLI は `Leanfmt.CLI` に閉じ、オプション解析や I/O を担当する
- デバッグ用途は `Leanfmt.Debug` に分離する
- ルート直下の Lean ファイルは `Main.lean` / `Leanfmt.lean` のみ
- テストケースは leaf ディレクトリに `In.lean` / `Out.lean` のみを配置

---
updated_at: 2026-02-01
