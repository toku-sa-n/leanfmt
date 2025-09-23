#!/usr/bin/env python3
"""
Hook to protect specific files from being edited.
"""
import sys
import json
import os

def main():
    # Read the tool use data from stdin
    try:
        data = json.load(sys.stdin)
    except:
        # If we can't read the data, allow the operation
        sys.exit(0)
    
    # Check if this is an Edit or Write operation
    tool_name = data.get("tool_name", "")
    if tool_name not in ["Edit", "Write", "MultiEdit"]:
        # Not an edit operation, allow it
        sys.exit(0)
    
    # Get the file path from parameters
    tool_input = data.get("tool_input", {})
    file_path = tool_input.get("file_path", "")
    
    # Get the project directory from environment variable
    project_dir = os.environ.get("CLAUDE_PROJECT_DIR", "")
    
    # List of protected files (relative to project directory)
    protected_files = [
        os.path.join(project_dir, "scripts/run-tests.sh"),
        os.path.join(project_dir, "scripts/stop-hook.sh"),
        os.path.join(project_dir, "scripts/pre-commit-tests.sh"),
        os.path.join(project_dir, "scripts/git-command-filter.sh"),
        os.path.join(project_dir, ".claude/settings.json"),
        os.path.join(project_dir, "scripts/protect-files-edit.py")
    ]
    
    # Check if the file is protected
    if file_path in protected_files:
        response = {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": f"Editing {file_path} is not allowed. This file is protected from modifications."
            }
        }
        print(json.dumps(response))
        sys.exit(0)
    
    # Allow the operation - need to explicitly output allow
    response = {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "allow"
        }
    }
    print(json.dumps(response))
    sys.exit(0)

if __name__ == "__main__":
    main()
