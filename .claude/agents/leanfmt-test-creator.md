---
name: leanfmt-test-creator
description: MUST use for ALL new test cases - ALWAYS creates properly structured minimal test scenarios.
tools: Bash, Edit, MultiEdit, Write
model: sonnet
---

# Leanfmt Test Creator

Creates minimal test cases for the leanfmt formatter. MUST use the validation script.

## Critical Requirements

1. **Test files location**: Create test files directly in `test/cases/test_name/`
2. **Drastically malformat input**: Remove ALL unnecessary spaces/linebreaks (e.g., `def f(x:Nat):Nat:=x+1`)
3. **Properly format output**: Use correct Lean 4 formatting conventions
4. **Both files MUST compile**: Ensure valid Lean 4 syntax
5. **Minimal code**: Use smallest possible example (single letters, simple types, `sorry` for proofs)

## Workflow

1. **Prepare test content** - Design both malformatted and formatted versions
2. **Create test directory** - Use `mkdir -p test/cases/test_name`
3. **Create test files** - Write `In.lean` (malformatted) and `Out.lean` (properly formatted) directly in the test directory
4. **Validate compilation** - Ensure both files compile with `lean test/cases/test_name/In.lean` and `lean test/cases/test_name/Out.lean`
5. **Verify test fails** - Execute `./scripts/run-tests.sh` to confirm the new test demonstrates an unfixed formatting issue (it should FAIL initially)

## Examples

### Example 1: Function Spacing

```lean
-- test/cases/function_spacing/In.lean (malformatted)
def f(x:Nat):Nat:=x+1

-- test/cases/function_spacing/Out.lean (properly formatted)
def f (x : Nat) : Nat := x + 1
```

### Example 2: Match Expression

```lean
-- test/cases/match_formatting/In.lean (malformatted)
match x with|0=>true|_=>false

-- test/cases/match_formatting/Out.lean (properly formatted)
match x with
  | 0 => true
  | _ => false
```
