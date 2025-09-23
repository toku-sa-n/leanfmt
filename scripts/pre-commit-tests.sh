#!/bin/bash

# Simple pre-commit hook that runs lake test

set -e

echo "Running pre-commit hook: lake test"
lake test