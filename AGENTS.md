# Leanfmt Agents

## Project Overview

**Leanfmt** is a code formatter for Lean 4 that automatically reformats Lean source code according to consistent style rules. It parses Lean source files and produces cleanly formatted output while preserving semantic meaning.

> **IMPORTANT:** All Leanfmt development must use specialized agents. Never attempt tasks directly - each agent contains domain-specific knowledge and handles all necessary validation automatically.

## Code Style Guidelines

### No-Comments Policy

**Leanfmt follows a strict no-comments policy for all Lean code.** Code should be self-documenting through:

- **Clear, descriptive naming:** Functions, variables, and types should have names that clearly express their purpose
- **Logical structure:** Code organization should make the flow and intent obvious
- **Appropriate abstraction:** Complex logic should be broken into well-named helper functions

**Never add obvious comments that simply restate what the code does.** Examples of prohibited comments:

```lean
-- This function adds two numbers
def add (a b : Nat) : Nat := a + b

-- Increment x by 1
let x := x + 1
```

The code should speak for itself. If code requires explanation, consider refactoring it to be clearer instead of adding comments.

## Agent Reference

| Task                     | Agent                           | Purpose                                          |
| ------------------------ | ------------------------------- | ------------------------------------------------ |
| Creating test cases      | `leanfmt-test-creator`          | Generates properly structured test scenarios     |
| Fixing formatting bugs   | `leanfmt-bug-fixer`             | Implements correct bug fixes with proper testing |
| Running tests            | `test-runner`                   | Executes test suite and validates results        |
| Checking self-formatting | `leanfmt-self-format-checker`   | Verifies formatter can format its own codebase   |
| Researching Lean 4 style | `lean4-style-researcher`        | Determines canonical Lean 4 formatting rules     |
| Writing Lean 4 code      | `lean4-code-writer`             | Creates idiomatic Lean 4 implementations         |
| Refactoring Lean 4 code  | `lean4-refactorer`              | Safely restructures existing code                |
| Creating shell scripts   | `shell-script-writer`           | Develops robust shell automation                 |
| Writing documentation    | `markdown-writer`               | Produces professional technical documentation    |
| Modifying GitHub Actions | `github-actions-writer`         | Maintains CI/CD workflows with best practices    |
| Creating Claude agents   | `claude-agent-writer`           | Develops specialized agents with enforced usage  |
| Investigating breakages  | `leanfmt-breakage-investigator` | Diagnoses and resolves test failures             |
| Restoring workspace      | `leanfmt-workspace-fixer`       | Safely restores working environment              |

All agent specifications are available in `.claude/agents/` directory.

## Additional Resources

### External Documentation

- **[Lean 4 Documentation](https://lean-lang.org/documentation/):** Official language reference and tutorials
- **[Lake Build System](https://github.com/leanprover/lake):** Build tool documentation and configuration guide
- **[Project Issue Tracker](https://github.com/toku-sa-n/leanfmt/issues):** Bug reports and feature requests

### Project Documentation

- **[README.md](./README.md):** Project overview and quick start guide
- **[Agent Files](.claude/agents/):** Individual agent specifications with detailed workflows
