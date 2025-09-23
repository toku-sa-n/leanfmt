#!/bin/bash

# Stop hook for Claude Code with integrated CI checks
# =====================================================
#
# This script enforces that:
# 1. No uncommitted changes exist
# 2. Selected CI checks pass (excluding self-formatting)
# 3. Optional success notification via ntfy.sh
#
# Exit codes:
#   0 - All checks passed
#   2 - One or more checks failed
#
# Notification Configuration:
#   NTFY_TOPIC - ntfy.sh topic name (required for notifications)

set -euo pipefail

# Handle locale warnings - use C.UTF-8 for better compatibility
export LC_ALL=C.UTF-8 2>/dev/null || export LC_ALL=C

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly CORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

# Notification configuration
readonly PROJECT_NAME="$(basename "${PROJECT_ROOT}")"

# Track overall status
OVERALL_STATUS=0
declare -a FAILED_CHECKS=()

# Helper functions
print_header() {
    local title="$1"
    echo
    echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}  ${title}${NC}"
    echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"
}

print_status() {
    local check_name="$1"
    local status="$2"

    if [ "$status" -eq 0 ]; then
        echo -e "${GREEN}✓${NC} ${check_name} passed"
    else
        echo -e "${RED}✗${NC} ${check_name} failed"
        FAILED_CHECKS+=("$check_name")
        OVERALL_STATUS=2
    fi
}

# Send success notification via ntfy.sh if configured
send_success_notification() {
    # Only send notification if NTFY_TOPIC is configured
    if [ -z "${NTFY_TOPIC:-}" ]; then
        return 0
    fi

    local message="✅ All CI checks passed for ${PROJECT_NAME}"

    # Send notification to ntfy.sh (suppress output to avoid noise)
    if ! curl -s -f \
        -d "${message}" \
        "https://ntfy.sh/${NTFY_TOPIC}" >/dev/null 2>&1; then
        echo -e "${YELLOW}Warning: Failed to send notification to ntfy.sh${NC}" >&2
    fi
}

# Pre-flight check functions
check_git_status() {
    print_header "Pre-flight: Checking Git Status"
    echo "Checking for uncommitted changes..."

    # Check if there are any uncommitted changes (staged or unstaged)
    if ! git diff --quiet || ! git diff --cached --quiet; then
        echo -e "${BOLD}${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}${RED}  ❌ Uncommitted Changes Detected${NC}"
        echo -e "${BOLD}${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo
        echo "The repository has uncommitted changes. CI cannot run with uncommitted files."
        echo
        echo "Modified files:"
        git status --short
        echo
        echo -e "${YELLOW}Please ask Claude Code to commit these changes before running CI.${NC}"
        echo "Example: 'Please commit all changes with an appropriate message'"
        echo
        exit 2
    fi

    # Check for untracked files
    if [ -n "$(git ls-files --others --exclude-standard)" ]; then
        echo -e "${BOLD}${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}${RED}  ❌ Untracked Files Detected${NC}"
        echo -e "${BOLD}${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo
        echo "The repository has untracked files. CI cannot run with untracked files."
        echo
        echo "Untracked files:"
        git ls-files --others --exclude-standard | head -20
        echo
        echo -e "${YELLOW}Please ask Claude Code to add and commit these files, or add them to .gitignore.${NC}"
        echo "Example: 'Please add all untracked files and commit them'"
        echo
        exit 2
    fi

    echo -e "${GREEN}✓ Git status clean - no uncommitted changes${NC}"
}

check_build() {
    print_header "Pre-flight: Building Project"
    echo "Building leanfmt..."
    if ! lake build leanfmt; then
        echo -e "${RED}Build failed! Cannot proceed with CI checks.${NC}"
        exit 2
    fi
    echo -e "${GREEN}✓ Build successful${NC}"
}

# CI check functions
check_test_inputs_malformatted() {
    print_header "Check 1/5: Validate Test Inputs Are Malformatted"
    echo "Ensuring all In.lean files are intentionally malformatted..."

    local check_status=0
    local malformatted_count=0
    local -a formatted_files=()

    # Create temporary file to collect results
    local temp_result
    temp_result=$(mktemp)
    trap "rm -f $temp_result" EXIT

    echo "Running: find test/cases -name \"In.lean\" -print0 | xargs -0 -I {} -P \$(nproc) sh -c 'if lake exe leanfmt --check {}; then exit 1; else exit 0; fi'"

    # Run the parallel check exactly like GitHub Actions
    if find test/cases -name "In.lean" -print0 | xargs -0 -I {} -P $(nproc) sh -c 'if lake exe leanfmt --check {} >/dev/null 2>&1; then echo "FORMATTED:{}" >> "'"$temp_result"'"; exit 1; else exit 0; fi'; then
        # All files are malformatted (expected)
        check_status=0
    else
        # Some files are formatted (error)
        check_status=1
    fi

    # Count files and check for formatted ones
    malformatted_count=$(find test/cases -name "In.lean" -type f | wc -l)
    if [ -f "$temp_result" ]; then
        while IFS= read -r line; do
            if [[ "$line" == FORMATTED:* ]]; then
                formatted_files+=("${line#FORMATTED:}")
            fi
        done < "$temp_result"
    fi

    if [ ${#formatted_files[@]} -gt 0 ]; then
        echo -e "${RED}ERROR: The following In.lean files are properly formatted but should be malformatted:${NC}"
        for file in "${formatted_files[@]}"; do
            echo "  - $file"
        done
    else
        echo "Checked $malformatted_count In.lean files - all correctly malformatted"
    fi

    print_status "Test inputs malformatted" "$check_status"
    return $check_status
}

check_markdown_lint() {
    print_header "Check 2/5: Markdown Lint Check"
    echo "Checking Markdown files for style issues..."

    local check_status=0
    if command -v npx >/dev/null 2>&1; then
        echo "Running: npx markdownlint-cli2 **/*.md"
        
        if npx markdownlint-cli2 **/*.md; then
            echo "All Markdown files pass lint checks"
        else
            echo -e "${RED}Some Markdown files have lint issues${NC}"
            echo "Fix the issues above or configure .markdownlint.json to adjust rules"
            check_status=1
        fi
    else
        echo -e "${YELLOW}WARNING: npx not found - skipping Markdown lint check${NC}"
        echo "Install Node.js to enable Markdown linting"
    fi

    print_status "Markdown lint check" "$check_status"
    return $check_status
}

check_prettier_format() {
    print_header "Check 3/5: Prettier Format Check"
    echo "Checking non-Lean file formatting with Prettier..."

    local check_status=0
    if command -v npx >/dev/null 2>&1; then
        echo "Running: npx prettier --check ."
        
        if npx prettier --check .; then
            echo "All files pass Prettier formatting"
        else
            echo -e "${RED}Some files need Prettier formatting${NC}"
            echo "To fix: npx prettier --write ."
            check_status=1
        fi
    else
        echo -e "${YELLOW}WARNING: npx not found - skipping Prettier check${NC}"
        echo "Install Node.js to enable Prettier checking"
    fi

    print_status "Prettier format check" "$check_status"
    return $check_status
}

check_test_suite() {
    print_header "Check 4/5: Test Suite"
    echo "Running full test suite..."

    local check_status=0
    if lake test; then
        echo "All tests passed"
    else
        echo -e "${RED}Test suite failed${NC}"
        check_status=1
    fi

    print_status "Test suite" "$check_status"
    return $check_status
}

check_test_file_compilation() {
    # Part A: Test File Compilation
    echo "Verifying all test files compile with Lean compiler..."
    echo "Running: find test/cases -name \"*.lean\" -print0 | xargs -0 -I {} -P \$(nproc) sh -c 'lean {} || exit 1'"

    local total_files
    total_files=$(find test/cases -name "*.lean" -type f | wc -l)

    if find test/cases -name "*.lean" -print0 | xargs -0 -I {} -P $(nproc) sh -c 'lean {} >/dev/null 2>&1 || exit 1'; then
        echo "All $total_files test files compiled successfully"
        print_status "Test file compilation" 0
        return 0
    else
        echo -e "${RED}Some test files failed to compile${NC}"
        print_status "Test file compilation" 1
        return 1
    fi
}

check_test_output_idempotency() {
    # Part B: Test Output Idempotency  
    echo
    echo "Verifying all Out.lean files are idempotent..."
    echo "Running: find test/cases -name \"Out.lean\" -print0 | xargs -0 -I {} -P \$(nproc) lake exe leanfmt --check {}"

    local out_file_count
    out_file_count=$(find test/cases -name "Out.lean" -type f | wc -l)

    if find test/cases -name "Out.lean" -print0 | xargs -0 -I {} -P $(nproc) lake exe leanfmt --check {}; then
        echo "All $out_file_count Out.lean files are idempotent"
        print_status "Test output idempotency" 0
        return 0
    else
        echo -e "${RED}Some Out.lean files are not idempotent (would change if formatted again)${NC}"
        print_status "Test output idempotency" 1
        return 1
    fi
}

main() {
    # Change to project root
    cd "${PROJECT_ROOT}"

    echo -e "${BOLD}${YELLOW}CI Pipeline (Stop Hook)${NC}"
    echo -e "Running CI checks locally"
    echo -e "Using ${CORES} parallel cores for execution"

    # Pre-flight checks
    check_git_status
    check_build

    # Run CI checks - collect results for notification
    local failed_check=""

    if ! check_test_inputs_malformatted; then
        failed_check="Test inputs malformatted"
    elif ! check_markdown_lint; then
        failed_check="Markdown lint check"
    elif ! check_prettier_format; then
        failed_check="Prettier format check"
    elif ! check_test_suite; then
        failed_check="Test suite"
    else
        # Check 5 split into two parts for proper header display
        print_header "Check 5/5: Test File Compilation and Idempotency"

        if ! check_test_file_compilation; then
            failed_check="Test file compilation"
        elif ! check_test_output_idempotency; then
            failed_check="Test output idempotency"
        fi
    fi

    # Exit if any check failed
    if [ -n "$failed_check" ]; then
        echo -e "\n${BOLD}${RED}CI Pipeline aborted due to failed check.${NC}"
        exit 2
    fi

    # If we get here, all checks passed
    echo
    echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${GREEN}  ✅ All CI checks passed!${NC}"
    echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo "Your code is ready for submission to GitHub."

    # Send success notification
    send_success_notification

    exit 0
}

# Execute main function
main "$@"
