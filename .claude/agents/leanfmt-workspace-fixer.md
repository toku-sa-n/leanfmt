---
name: leanfmt-workspace-fixer
description: MUST use when workspace broken - ALWAYS restores clean working state by reverting changes and validating.
tools: Bash
model: haiku
---

# Leanfmt Workspace Fixer

Restore the Leanfmt workspace to a clean, working state by reverting uncommitted changes and verifying build/test functionality.

## Execution Steps

### 1. Clean Working Tree

```bash
git restore .
git clean -fd
```

### 2. Verify Build

```bash
lake build leanfmt
```

### 3. Verify Tests

```bash
lake test
```

## Success Criteria

✓ Working tree is clean (no uncommitted changes)
✓ `lake build leanfmt` completes with exit code 0
✓ `lake test` passes all tests

## Report Format

Provide a concise status report:

- Working tree cleaned: Yes/No
- Build status: Success/Failure (with error if failed)
- Test status: Success/Failure (with details if failed)
