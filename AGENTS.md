# Repository Guidelines

## Project Structure & Module Organization

Source modules live under `Leanfmt/` and should stay small enough that each file owns a single formatter concern. `Main.lean` hosts the CLI entry point, while `Leanfmt.lean` re-exports the public API—keep them the only `.lean` files in the repository root. Functional tests live in `test/cases/<topic>/<sample>/` as `In.lean` and `Out.lean` pairs; reuse an existing topic directory when possible, or fall back to `basic/`.

## Build, Test, and Development Commands

- `lake build leanfmt` builds the formatter binary at `.lake/build/bin/leanfmt`.
- `lake exe leanfmt <path>` formats a file; add `--check 'Leanfmt/**/*.lean'` to fail on unformatted sources.
- `lake exe runtests` executes the Lean-based driver defined in `test/RunTests.lean`.
- `./scripts/run-tests.sh` rebuilds the binary, executes every case in parallel, and prints colored diffs.
- `./scripts/validate-test-structure.sh` confirms each case folder contains both `In.lean` and `Out.lean`.

## Coding Style & Naming Conventions

Use Lean’s default two-space indentation and align continuations beneath opening keywords (`match`, `where`, `let`). Modules, structures, and constants are PascalCase; functions, tactics, and locals are camelCase; CLI flags or Bash variables stay snake_case. Any public definition must be re-exported from `Leanfmt.lean`. Run `lake exe leanfmt --in-place` before committing, and never add new `.lean` files to the root directory.

## Testing Guidelines

Each formatter scenario is expressed as an `In.lean` fixture plus the expected `Out.lean`. The test harness also re-runs the formatter on `Out.lean`, so capture the stabilized result (format twice and check for changes). When fixing a bug, add a descriptive topic/sample path and document intent in a short comment at the top of `In.lean`. Always finish with `./scripts/run-tests.sh` to mirror the CI pipeline and catch idempotency regressions early.

## Commit & Pull Request Guidelines

Follow the existing Conventional Commit flavor seen in history (`feat: format example (#12)`, `chore: run act workflow (#8)`). Keep commits focused—split formatting-only changes from semantic ones and exclude generated artifacts. Pull requests should outline the motivation, summarize impact, link related issues, and list verification steps such as `lake exe leanfmt --check` or `./scripts/run-tests.sh`. Bug fixes should ship with the new reproduction case and close the relevant issue via `Fixes #NN`.

## Security & Configuration Tips

Tooling versions are locked by `lean-toolchain`; run `lake update` after switching versions to refresh dependencies. `./scripts/pre-commit-tests.sh` bundles the quick checks you should run before pushing. Avoid editing `.lake/` manually—clear it only when the build cache is corrupted (`rm -rf .lake && lake build leanfmt`).
