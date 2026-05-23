#!/usr/bin/env bash
# lib/commands/lessons/index.sh — Índice de módulos lessons

# shellcheck disable=SC1091,SC2086,SC2034,SC2015,SC2001,SC2162,SC1090,SC1010,SC2164,SC2155,SC2094,SC2005,SC2317,SC2129,SC2126,SC2120,SC2119,SC2116,SC2046

# ============================================================
# LESSONS MODULES INDEX
# Carrega todos os módulos de lessons
# ============================================================

# Get directory of this index file
LESSONS_COMMANDS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load all modules in order
source "${LESSONS_COMMANDS_DIR}/capture.sh"
source "${LESSONS_COMMANDS_DIR}/list.sh"
source "${LESSONS_COMMANDS_DIR}/search.sh"
source "${LESSONS_COMMANDS_DIR}/approve.sh"
source "${LESSONS_COMMANDS_DIR}/validate.sh"
source "${LESSONS_COMMANDS_DIR}/compile.sh"
source "${LESSONS_COMMANDS_DIR}/migrate.sh"

# Re-export all functions
export -f lessons::capture 2>/dev/null || true
export -f lessons::list 2>/dev/null || true
export -f lessons::search 2>/dev/null || true
export -f lessons::approve 2>/dev/null || true
export -f lessons::validate 2>/dev/null || true
export -f lessons::compile 2>/dev/null || true
export -f lessons::migrate 2>/dev/null || true

echo "[LESSONS] Módulos carregados: capture, list, search, approve, validate, compile, migrate"
