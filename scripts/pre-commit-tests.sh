#!/bin/bash

set -euo pipefail

if ! command -v act >/dev/null 2>&1; then
    echo "pre-commit hook error: act is not installed or not in PATH" >&2
    exit 1
fi

echo "Running pre-commit hook: act pull_request (PR workflow)"
act pull_request
