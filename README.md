# leanfmt

A fast, opinionated code formatter for Lean 4 that automatically formats source code according to consistent style rules. Built on Lean's native parser for reliable performance with support for multiple output modes and easy CLI integration.

## Installation

**Prerequisites:** Lean 4 and Lake

```bash
git clone https://github.com/toku-sa-n/leanfmt.git
cd leanfmt
lake build leanfmt
```

After building, use `lake exe leanfmt` to run the formatter.

## Usage

```bash
# Format a single file and view the result
lake exe leanfmt Main.lean

# Format a file in-place (overwrites the original)
lake exe leanfmt --in-place Main.lean

# Check if your files are properly formatted
lake exe leanfmt --check src/**/*.lean
```

## License

Apache License 2.0 - see [licenses/leanfmt](licenses/leanfmt).

This project uses templates from [cc-sdd](https://github.com/gotalab/cc-sdd), and the license file is [licenses/cc-sdd](licenses/cc-sdd).
