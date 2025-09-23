#!/bin/bash
# Uses direct binary path because 'lake exe' in parallel results in weird errors

set -euo pipefail
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly LEANFMT_BIN="$PROJECT_ROOT/.lake/build/bin/leanfmt"
readonly TEST_CASES_DIR="$PROJECT_ROOT/test/cases"
readonly CORES="$(nproc)"
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'
declare -g TOTAL_TESTS=0
declare -g PASSED_TESTS=0
declare -g FAILED_TESTS=0
declare -ag FAILED_TEST_NAMES=()
declare -g TEMP_DIR=""
cleanup() {
    local exit_code=$?
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
    return $exit_code
}
print_introduction() {
    echo -e "${YELLOW}Test Runner${NC}"
    echo "This script will:"
    echo "  1. Check for unauthorized Lean files in project root"
    echo "  2. Build the formatter"
    echo "  3. Run all tests in parallel (using $CORES cores)"
    echo "  4. Report test results with diffs for any failures"
    echo
}
check_unauthorized_lean_files() {
    echo "Checking for unauthorized Lean files in project root..."

    local unauthorized_files
    unauthorized_files=$(find "$PROJECT_ROOT" -maxdepth 1 -name "*.lean" -type f | grep -v "Main.lean" | grep -v "Leanfmt.lean" || true)

    if [[ -n "$unauthorized_files" ]]; then
        echo -e "${RED}ERROR: Unauthorized Lean files found in project root!${NC}"
        echo ""
        echo "Only Main.lean and Leanfmt.lean are allowed in the project root."
        echo "Please move other Lean files to appropriate subdirectories."
        echo ""
        echo "Unauthorized files:"
        echo "$unauthorized_files" | while IFS= read -r file; do
            echo "  - $(basename "$file")"
        done
        echo ""
        return 1
    fi

    echo -e "${GREEN}✓ No unauthorized Lean files in project root${NC}"
    echo
}
build_formatter() {
    echo "Building leanfmt..."

    # Change to project root for build to ensure proper context
    cd "$PROJECT_ROOT"
    lake build leanfmt

    if [[ ! -f "$LEANFMT_BIN" ]]; then
        echo -e "${RED}ERROR: Failed to build leanfmt binary at $LEANFMT_BIN${NC}"
        return 1
    fi

    echo -e "${GREEN}✓ Leanfmt binary built successfully at $LEANFMT_BIN${NC}"
}
discover_test_files() {
    local -n test_files_ref=$1

    echo "Discovering test cases..."
    mapfile -t test_files_ref < <(find "$TEST_CASES_DIR" -name "In.lean" | sort)

    if [[ ${#test_files_ref[@]} -eq 0 ]]; then
        echo "No test cases found in $TEST_CASES_DIR/"
        return 1
    fi

    echo "Found ${#test_files_ref[@]} test cases"
    echo
}
show_diff() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"
    local diff_type="$4"  # "Output" or "Idempotency"

    echo -e "${RED}✗${NC} $test_name: $diff_type mismatch"
    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
    local temp_expected temp_actual
    temp_expected=$(mktemp)
    temp_actual=$(mktemp)
    cleanup_temps() {
        rm -f "$temp_expected" "$temp_actual"
    }
    trap cleanup_temps RETURN

    echo "$expected" > "$temp_expected"
    echo "$actual" > "$temp_actual"
    if command -v colordiff >/dev/null 2>&1; then
        colordiff -u "$temp_expected" "$temp_actual" | \
            sed "1s|$temp_expected|Expected (Out.lean)|; 2s|$temp_actual|Actual (formatted output)|" || true
    elif diff --color=auto /dev/null /dev/null >/dev/null 2>&1; then
        diff --color=auto -u "$temp_expected" "$temp_actual" | \
            sed "1s|$temp_expected|Expected (Out.lean)|; 2s|$temp_actual|Actual (formatted output)|" || true
    else
        echo -e "${BLUE}Expected (Out.lean):${NC}"
        diff -u "$temp_expected" "$temp_actual" | \
            sed "1s|$temp_expected|Expected|; 2s|$temp_actual|Actual|" || true
    fi

    echo -e "${CYAN}────────────────────────────────────────────────${NC}"
}
run_leanfmt() {
    local input_file="$1"
    local -n output_ref="$2"
    local -n error_ref="$3"

    local temp_err
    temp_err=$(mktemp)
    trap "rm -f '$temp_err'" RETURN

    if output_ref=$("$LEANFMT_BIN" "$input_file" 2>"$temp_err"); then
        error_ref=$(cat "$temp_err")
        return 0
    else
        local exit_code=$?
        error_ref=$(cat "$temp_err")
        return $exit_code
    fi
}
run_test() {
    local in_file="$1"
    local output_file="$2"

    local test_dir out_file test_name
    test_dir=$(dirname "$in_file")
    test_name=$(echo "$test_dir" | sed "s|$TEST_CASES_DIR/||")
    out_file="$test_dir/Out.lean"
    exec 3>&1 4>&2
    exec 1>"$output_file" 2>&1
    restore_descriptors() {
        exec 1>&3 2>&4
    }
    trap restore_descriptors RETURN
    if [[ ! -f "$out_file" ]]; then
        echo -e "${RED}✗${NC} $test_name: Out.lean not found"
        return 1
    fi

    local expected_output actual_output error_output
    expected_output=$(cat "$out_file")
    if ! run_leanfmt "$in_file" actual_output error_output; then
        echo -e "${RED}✗${NC} $test_name: Leanfmt failed to format In.lean"
        if [[ -n "$error_output" ]]; then
            echo -e "${RED}Error output:${NC}"
            echo "$error_output" | sed 's/^/  /'
        fi
        return 1
    fi

    if [[ "$actual_output" != "$expected_output" ]]; then
        show_diff "$test_name" "$expected_output" "$actual_output" "Output"
        return 1
    fi
    local idempotent_output idempotent_error
    if ! run_leanfmt "$out_file" idempotent_output idempotent_error; then
        echo -e "${RED}✗${NC} $test_name: Leanfmt failed to format Out.lean (idempotency test)"
        if [[ -n "$idempotent_error" ]]; then
            echo -e "${RED}Error output:${NC}"
            echo "$idempotent_error" | sed 's/^/  /'
        fi
        return 1
    fi

    if [[ "$idempotent_output" != "$expected_output" ]]; then
        show_diff "$test_name" "$expected_output" "$idempotent_output" "Idempotency"
        return 1
    fi

    echo -e "${GREEN}✓${NC} $test_name"
    return 0
}
run_and_save() {
    local in_file="$1"
    local test_name output_file result_file

    test_name=$(echo "$(dirname "$in_file")" | sed "s|$TEST_CASES_DIR/||")
    output_file="$TEMP_DIR/$(echo "$test_name" | tr '/' '_').output"
    result_file="$TEMP_DIR/$(echo "$test_name" | tr '/' '_').result"

    if run_test "$in_file" "$output_file"; then
        echo "PASS" > "$result_file"
    else
        echo "FAIL" > "$result_file"
    fi
}
setup_parallel_execution() {
    export -f run_test run_and_save show_diff run_leanfmt
    export RED GREEN YELLOW BLUE CYAN NC
    export LEANFMT_BIN TEMP_DIR TEST_CASES_DIR
    TEMP_DIR=$(mktemp -d)
    trap cleanup EXIT
}
run_tests_parallel() {
    local -n test_files_ref=$1

    echo "Running ${#test_files_ref[@]} tests using $CORES parallel jobs..."
    echo

    if command -v parallel >/dev/null 2>&1; then
        printf '%s\n' "${test_files_ref[@]}" | parallel -j "$CORES" run_and_save {} 2>/dev/null
    else
        printf '%s\0' "${test_files_ref[@]}" | xargs -0 -P "$CORES" -I {} bash -c 'run_and_save "$@"' _ {} 2>/dev/null
    fi
    sleep 0.1
}
process_test_results() {
    local -n test_files_ref=$1

    echo "Processing test results..."
    for in_file in "${test_files_ref[@]}"; do
        local test_name result_file output_file
        test_name=$(echo "$(dirname "$in_file")" | sed "s|$TEST_CASES_DIR/||")
        result_file="$TEMP_DIR/$(echo "$test_name" | tr '/' '_').result"
        output_file="$TEMP_DIR/$(echo "$test_name" | tr '/' '_').output"
        if [[ -f "$output_file" ]]; then
            cat "$output_file"
        fi
        if [[ -f "$result_file" && "$(cat "$result_file")" = "PASS" ]]; then
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            FAILED_TESTS=$((FAILED_TESTS + 1))
            FAILED_TEST_NAMES+=("$test_name")
        fi
    done

    TOTAL_TESTS=${#test_files_ref[@]}
}
display_final_summary() {
    echo
    echo "═══════════════════════════════════════════════"
    echo "Test Results: $PASSED_TESTS/$TOTAL_TESTS passed"
    echo "═══════════════════════════════════════════════"

    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${GREEN}✓ All tests passed!${NC}"
        echo "Claude Code: Please create a git commit with these changes."
        echo
        echo "AGENT USAGE REQUIREMENTS:"
        echo "- You MUST use specialized agents proactively"
        echo "- Use the appropriate agent for creating commits"
        echo "- Do NOT attempt manual git operations"
        echo "- Be PROACTIVE - create the commit without being asked"
        echo
        echo "The code is working correctly and all tests pass."
        echo "This is a good checkpoint to commit the changes."
        return 0
    else
        echo -e "${RED}✗ $FAILED_TESTS tests failed${NC}"
        if [[ ${#FAILED_TEST_NAMES[@]} -gt 0 ]]; then
            echo
            echo "Failed tests:"
            for test_name in "${FAILED_TEST_NAMES[@]}"; do
                echo "  - $test_name"
            done
        fi
        return 1
    fi
}
main() {
    print_introduction
    check_unauthorized_lean_files
    build_formatter

    local test_files=()
    discover_test_files test_files

    setup_parallel_execution
    run_tests_parallel test_files
    process_test_results test_files
    display_final_summary
    local exit_code=$?
    cleanup
    exit $exit_code
}
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
