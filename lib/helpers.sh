#!/usr/bin/env bash
# lib/helpers.sh - DEVORQ Helper Functions
# Exit codes: 0=sucesso, 1=erro, 2=invalid_args, 3=not_found, 4=validation_failed, 5=permission_denied

# Exit codes (constantes globais)
# SC2168: These are valid since file is sourced, not executed directly
EXIT_SUCCESS=0
EXIT_ERROR=1
EXIT_INVALID_ARGS=2
EXIT_NOT_FOUND=3
EXIT_VALIDATION_FAILED=4
EXIT_PERMISSION_DENIED=5

# Sanitize input - remove dangerous characters
sanitize_input() {
    local input="${1:-}"
    if [ -z "$input" ]; then
        echo ""
        return 0
    fi
    echo "$input" | sed 's/[^a-zA-Z0-9._\-]//g'
}

# Validate path - ensure path is within base_dir
validate_path() {
    local path="$1"
    local base_dir="${2:-.}"
    if [ -z "$path" ]; then
        echo "Path required" >&2
        return $EXIT_INVALID_ARGS
    fi
    local real_path
    real_path=$(realpath "$path" 2>/dev/null) || {
        echo "Invalid path: $path" >&2
        return $EXIT_ERROR
    }
    local real_base
    real_base=$(realpath "$base_dir" 2>/dev/null) || {
        echo "Invalid base_dir: $base_dir" >&2
        return $EXIT_ERROR
    }
    case "$real_path" in
        "$real_base"/*)
            echo "$real_path"
            return $EXIT_SUCCESS
            ;;
        *)
            echo "Path $path is outside $base_dir" >&2
            return $EXIT_VALIDATION_FAILED
            ;;
    esac
}

# Require arg - check if arg is provided
require_arg() {
    local arg="$1"
    local name="$2"
    if [ -z "$arg" ]; then
        echo "Argument required: $name" >&2
        return $EXIT_INVALID_ARGS
    fi
    return $EXIT_SUCCESS
}

# Require file - check if file exists
require_file() {
    local file="$1"
    if [ ! -f "$file" ]; then
        echo "File not found: $file" >&2
        return $EXIT_NOT_FOUND
    fi
    return $EXIT_SUCCESS
}

# Log safe - remove credentials from log
log_safe() {
    local message="$1"
    echo "$message" | sed 's/password=.*/password=REDACTED/g' | sed 's/token=.*/token=REDACTED/g'
}
