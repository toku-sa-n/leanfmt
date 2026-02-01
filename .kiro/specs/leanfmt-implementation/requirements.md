# Requirements Document

## Introduction
本ドキュメントは、Lean 4 向けフォーマッタである Leanfmt の実装に必要な機能要件を定義する。対象は CLI とその整形結果の振る舞いであり、開発・CI の両方で一貫した整形結果と明確な失敗通知を提供することを目的とする。

## Requirements

### Requirement 1: 入力ソースの受け取り
**Objective:** As a Lean 開発者, I want Leanfmt がファイルまたは標準入力を受け取れる, so that 既存の開発フローとツール連携の両方で整形できる

#### Acceptance Criteria
1. When ユーザーがファイルパスを指定して実行したとき, the Leanfmt CLI shall 指定されたファイル内容を整形対象として読み込む
2. When ユーザーが標準入力から内容を渡したとき, the Leanfmt CLI shall 標準入力を整形対象として読み込む
3. If 指定された入力が存在しないまたは読み込みに失敗したとき, the Leanfmt CLI shall 読み込み失敗を示すエラーメッセージを出力する

### Requirement 2: 出力モードの切り替え
**Objective:** As a Lean 開発者, I want 出力モードを用途に応じて切り替えられる, so that ローカル整形・差分確認・CI チェックを同じ CLI で行える

#### Acceptance Criteria
1. When ユーザーが標準出力モードを選択したとき, the Leanfmt CLI shall 整形結果を標準出力へ出力する
2. When ユーザーが in-place モードを選択したとき, the Leanfmt CLI shall 整形結果で入力ファイルを上書きする
3. When ユーザーが check モードを選択したとき, the Leanfmt CLI shall 整形結果と入力の一致可否を判定して結果を報告する
4. If 複数のモードが同時に指定されて競合したとき, the Leanfmt CLI shall 競合を示すエラーメッセージを出力する

### Requirement 3: 整形結果の一貫性
**Objective:** As a Lean 開発者, I want 同じ入力から常に同じ整形結果を得たい, so that チームや CI で結果がぶれない

#### Acceptance Criteria
1. The Leanfmt CLI shall 同一の入力に対して決定的な整形結果を出力する
2. When 整形済みの出力を再度整形したとき, the Leanfmt CLI shall 同一の出力を生成する
3. While 入力が Lean 4 の構文として有効であるとき, the Leanfmt CLI shall 構文的に有効な出力を生成する

### Requirement 4: エラーと診断の明確化
**Objective:** As a Lean 開発者, I want 失敗理由を明確に把握したい, so that 修正や再実行の判断ができる

#### Acceptance Criteria
1. If 入力が Lean 4 の構文として無効なとき, the Leanfmt CLI shall 解析失敗を示すエラーメッセージを出力する
2. If 整形結果の書き込みに失敗したとき, the Leanfmt CLI shall 書き込み失敗を示すエラーメッセージを出力する
3. If 未知または無効なオプションが指定されたとき, the Leanfmt CLI shall 使用方法を含むエラーメッセージを出力する

### Requirement 5: CI・自動化向けの判定
**Objective:** As a CI 管理者, I want 整形差分の有無を機械的に判定したい, so that パイプラインで整形ルールを強制できる

#### Acceptance Criteria
1. When check モードで整形結果と入力が一致しないとき, the Leanfmt CLI shall 不一致を示す結果を報告し非成功の終了ステータスを返す
2. When check モードで整形結果と入力が一致するとき, the Leanfmt CLI shall 一致を示す結果を報告し成功の終了ステータスを返す
