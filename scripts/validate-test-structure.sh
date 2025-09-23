#!/bin/bash
set -euo pipefail

TEST_CASES_DIR="test/cases"
validation_errors=false

find_directories_with_files() {
    find "$TEST_CASES_DIR" -type d -exec sh -c 'find "$1" -maxdepth 1 -type f | grep -q . && echo "$1"' _ {} \;
}

find_invalid_intermediate_directories() {
    find "$TEST_CASES_DIR" -type d -exec sh -c '
        dir="$1"
        if [ "$dir" = "'"$TEST_CASES_DIR"'" ]; then
            exit 0
        fi
        if find "$dir" -maxdepth 1 -type f | grep -q .; then
            in_count=$(find "$dir" -maxdepth 1 -name "In.lean" | wc -l)
            out_count=$(find "$dir" -maxdepth 1 -name "Out.lean" | wc -l)
            total_count=$(find "$dir" -maxdepth 1 -type f | wc -l)
            if [ "$total_count" -ne 2 ] || [ "$in_count" -ne 1 ] || [ "$out_count" -ne 1 ]; then
                echo "$dir"
            fi
        fi
    ' _ {} \;
}

get_relative_path() {
    echo "${1#$TEST_CASES_DIR/}"
}

count_files_in_directory() {
    find "$1" -maxdepth 1 -type f | wc -l
}

has_unexpected_files() {
    find "$1" -maxdepth 1 -type f ! -name "In.lean" ! -name "Out.lean" | grep -q .
}

report_directory_contents() {
    local directory="$1"
    find "$directory" -maxdepth 1 -type f -exec basename {} \; | sed 's/^/    /'
}

report_unexpected_files() {
    local directory="$1"
    find "$directory" -maxdepth 1 -type f ! -name "In.lean" ! -name "Out.lean" -exec basename {} \; | sed 's/^/  /'
}

report_error() {
    echo "ERROR: $1"
    validation_errors=true
}

validate_test_cases_directory_exists() {
    if [ ! -d "$TEST_CASES_DIR" ]; then
        report_error "$TEST_CASES_DIR directory does not exist"
        exit 1
    fi
}

validate_no_intermediate_directories_have_files() {
    local invalid_dirs
    invalid_dirs=$(find_invalid_intermediate_directories)

    if [ -n "$invalid_dirs" ]; then
        report_error "Found intermediate directories containing files. Only leaf directories should contain files."
        for dir in $invalid_dirs; do
            local relative_path
            relative_path=$(get_relative_path "$dir")
            echo "  - $relative_path contains:"
            report_directory_contents "$dir"
        done
    fi
}

validate_leaf_directories_exist() {
    local leaf_directories
    leaf_directories=$(find_directories_with_files)

    if [ -z "$leaf_directories" ]; then
        report_error "No test case directories found in $TEST_CASES_DIR/"
        exit 1
    fi

    echo "$leaf_directories"
}

validate_test_case_directory() {
    local test_directory="$1"
    local relative_path
    relative_path=$(get_relative_path "$test_directory")

    echo "Validating test case: $relative_path"

    local file_count
    file_count=$(count_files_in_directory "$test_directory")

    if [ "$file_count" -ne 2 ]; then
        report_error "Test case '$relative_path' should contain exactly 2 files, but found $file_count"
        echo "Files in $relative_path:"
        find "$test_directory" -maxdepth 1 -type f -exec basename {} \; | sed 's/^/  /'
        return
    fi

    if [ ! -f "$test_directory/In.lean" ]; then
        report_error "Test case '$relative_path' is missing In.lean file"
    fi

    if [ ! -f "$test_directory/Out.lean" ]; then
        report_error "Test case '$relative_path' is missing Out.lean file"
    fi

    if has_unexpected_files "$test_directory"; then
        report_error "Test case '$relative_path' contains unexpected files. Only In.lean and Out.lean are allowed."
        echo "Unexpected files:"
        report_unexpected_files "$test_directory"
    fi
}

print_validation_summary() {
    if [ "$validation_errors" = true ]; then
        echo ""
        echo "Test structure validation failed. Please ensure:"
        echo "1. Only leaf directories (containing test cases) should have files"
        echo "2. All intermediate directories should contain only subdirectories"
        echo "3. Each test case directory contains exactly two files: In.lean and Out.lean"
        echo "4. Test cases can be at any depth within $TEST_CASES_DIR/"
        exit 1
    fi

    echo "Test structure validation passed!"
}

main() {
    echo "Validating $TEST_CASES_DIR directory structure..."

    validate_test_cases_directory_exists
    validate_no_intermediate_directories_have_files

    echo "Validating leaf directories..."
    local leaf_directories
    leaf_directories=$(validate_leaf_directories_exist)

    for test_directory in $leaf_directories; do
        validate_test_case_directory "$test_directory"
    done

    print_validation_summary
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi