#!/bin/bash

# This script filters git commands to prevent potentially dangerous operations
# It's called from .claude/settings.json as a PreToolUse hook

# Read the JSON input from stdin
json_input=$(cat)

# Extract the command from the JSON
command=$(echo "$json_input" | jq -r '.tool_input.command')

# Remove line continuations and normalize whitespace to prevent bypass attempts
# This handles cases like: git commit \
#                          --no-verify
command=$(echo "$command" | tr '\n' ' ' | sed 's/\\//g' | tr -s ' ')

# Define prohibited git operations
prohibited_patterns=(
    # Pushes only (commits are now allowed)
    "git[[:space:]]+push"
    
    # Configuration changes
    "git[[:space:]]+config"
    
    # Remote operations
    "git[[:space:]]+remote[[:space:]]+(add|set-url|rm|remove)"
    
    # Branch switching and merging
    "git[[:space:]]+checkout"
    "git[[:space:]]+switch"
    "git[[:space:]]+merge"
    "git[[:space:]]+rebase"
    
    # Dangerous reset operations
    "git[[:space:]]+reset[[:space:]]+--hard"
    
    # Force operations
    "git[[:space:]].*[[:space:]]+(--amend|--force|-f)"
    
    # Bypassing pre-commit hooks (both --no-verify and -n flag)
    "git[[:space:]]+commit[[:space:]].*--no-verify"
    "git[[:space:]]+commit[[:space:]].*-n([[:space:]]|$)"
    "git[[:space:]]+commit[[:space:]]+-[a-zA-Z]*n[a-zA-Z]*[[:space:]]"
    "git[[:space:]]+(-[a-zA-Z]|--[a-zA-Z-]+).*commit.*--no-verify"
    "git[[:space:]]+(-[a-zA-Z]|--[a-zA-Z-]+).*commit.*-n([[:space:]]|$)"
)

# Check if the command matches any prohibited pattern
for pattern in "${prohibited_patterns[@]}"; do
    if echo "$command" | grep -E "$pattern" > /dev/null 2>&1; then
        echo "Git operations that modify repository state or remotes are prohibited. Use approved scripts or ask for manual intervention." >&2
        echo "
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️  SECURITY VIOLATION DETECTED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Git operations that modify repository state or remotes are prohibited.

CLAUDE CODE: DO NOT ATTEMPT TO BYPASS THIS SECURITY CHECK.
ALL COMMITS MUST PASS VALIDATION CHECKS.

This is a security boundary that must not be crossed. Work within the
constraints and fix issues properly instead of trying to bypass them.

Use approved scripts or ask for manual intervention if needed.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        exit 2
    fi
done

# Command is allowed - exit successfully
exit 0
