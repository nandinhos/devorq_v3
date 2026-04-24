#!/usr/bin/env bash
# env-detect.sh — Auto-detect project environment for env-context skill
# Run at session start to generate environment context block
#
# Usage: env-detect.sh [--json]
#   --json  Output as JSON (for machine parsing)
#   default: Output as human-readable block

set -uo pipefail

MODE="human"
[ "${1:-}" = "--json" ] && MODE="json"

# ============================================================
# Helper functions
# ============================================================

has_command() {
    command -v "$1" &>/dev/null
}

has_file() {
    [ -f "$1" ]
}

get_project_name() {
    basename "$(pwd)"
}

# ============================================================
# Stack Detection
# ============================================================

detect_stack() {
    local -a stack_parts=()
    local runtime="Unknown"

    # PHP/Laravel
    if has_command php; then
        local php_version
        php_version=$(php -r 'echo PHP_VERSION;' 2>/dev/null || echo "unknown")
        stack_parts+=("PHP $php_version")
    fi

    if has_file composer.json; then
        if grep -q '"laravel/framework"' composer.json 2>/dev/null; then
            local laravel_version
            laravel_version=$(grep '"laravel/framework"' composer.json 2>/dev/null | grep -oP '"laravel/framework": "\K[^"]+' | cut -d'^' -f2 | head -1)
            stack_parts+=("Laravel ${laravel_version:-unknown}")
        fi
        if grep -q '"illuminate/' composer.json 2>/dev/null; then
            stack_parts+=("Illuminate components")
        fi
    fi

    # Node.js
    if has_command node; then
        local node_version
        node_version=$(node -v 2>/dev/null || echo "unknown")
        stack_parts+=("Node.js $node_version")
    fi

    if has_command npm; then
        local npm_version
        npm_version=$(npm -v 2>/dev/null || echo "unknown")
        stack_parts+=("npm $npm_version")
    fi

    # Python
    if has_command python3; then
        local py_version
        py_version=$(python3 --version 2>/dev/null || echo "unknown")
        stack_parts+=("$py_version")
    fi

    # Rust
    if has_command cargo; then
        local rust_version
        rust_version=$(cargo --version 2>/dev/null | cut -d' ' -f2 || echo "unknown")
        stack_parts+=("Rust $rust_version")
    fi

    # Go
    if has_command go; then
        local go_version
        go_version=$(go version 2>/dev/null | grep -oP 'go\K[0-9.]+' || echo "unknown")
        stack_parts+=("Go $go_version")
    fi

    # Java
    if has_command java; then
        local java_version
        java_version=$(java -version 2>&1 | head -1 | cut -d'"' -f2 || echo "unknown")
        stack_parts+=("Java $java_version")
    fi

    # Detect runtime environment
    if [ -f docker-compose.yml ] || [ -f docker-compose.yaml ]; then
        if grep -q "sail" docker-compose.yml 2>/dev/null; then
            runtime="Docker (Sail)"
        else
            runtime="Docker"
        fi
    elif has_command php && [ -f artisan ]; then
        runtime="Local (PHP built-in)"
    elif has_command node; then
        runtime="Local (Node)"
    else
        runtime="Local"
    fi

    # Build result
    local stack_str=""
    local part
    for part in "${stack_parts[@]}"; do
        [ -n "$stack_str" ] && stack_str="$stack_str,$part" || stack_str="$part"
    done

    echo "$stack_str"
    echo "RUNTIME:$runtime"
}

# ============================================================
# Commands Detection
# ============================================================

detect_commands() {
    local -a cmds=()

    if [ -f docker-compose.yml ] || [ -f docker-compose.yaml ]; then
        if grep -q "sail" docker-compose.yml 2>/dev/null; then
            cmds+=("vendor/bin/sail")
        fi
        cmds+=("docker-compose exec")
        cmds+=("docker exec")
    fi

    if [ -f artisan ]; then
        cmds+=("php artisan")
        cmds+=("composer")
    fi

    if [ -f package.json ]; then
        cmds+=("npm")
        cmds+=("npx")
    fi

    if [ -f pyproject.toml ] || [ -f requirements.txt ]; then
        cmds+=("pip")
        cmds+=("python")
    fi

    if [ -f Makefile ]; then
        cmds+=("make")
    fi

    if [ -f Cargo.toml ]; then
        cmds+=("cargo")
    fi

    local result=""
    local cmd
    for cmd in "${cmds[@]}"; do
        [ -n "$result" ] && result="$result,$cmd" || result="$cmd"
    done
    [ -z "$result" ] && result="none"
    echo "$result"
}

# ============================================================
# Ports Detection
# ============================================================

detect_ports() {
    local ports=""

    if [ -f docker-compose.yml ]; then
        local port
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            if echo "$line" | grep -qE '^\s+ports:'; then
                port=$(echo "$line" | grep -oE '[0-9]+:[0-9]+' | tr '\n' ',' | sed 's/,$//')
                [ -n "$ports" ] && ports="$ports;$port" || ports="$port"
            fi
        done < docker-compose.yml
    fi

    if [ -f .env ]; then
        local env_ports
        env_ports=$(grep -E "PORT|HOST" .env 2>/dev/null | grep -oE '[0-9]{4,5}' | sort -u | tr '\n' ',' | sed 's/,$//')
        [ -n "$env_ports" ] && [ -n "$ports" ] && ports="$ports;$env_ports" || ports="${env_ports:-}"
    fi

    [ -z "$ports" ] && ports="não detectado"
    echo "$ports"
}

# ============================================================
# Binaries Detection
# ============================================================

detect_binaries() {
    local -a bins=()
    local bin
    for bin in php node python3 composer npm pip cargo go java ruby perl sqlite3 mysql mysqldump psql mongosh redis-cli; do
        if has_command "$bin"; then
            bins+=("$bin")
        fi
    done

    local result=""
    local b
    for b in "${bins[@]}"; do
        [ -n "$result" ] && result="$result,$b" || result="$b"
    done
    [ -z "$result" ] && result="none"
    echo "$result"
}

# ============================================================
# Gotchas Detection
# ============================================================

detect_gotchas() {
    local -a gotchas=()

    # Docker + WWWUSER
    if [ -f docker-compose.yml ]; then
        if ! grep -q "WWWUSER" docker-compose.yml 2>/dev/null; then
            gotchas+=("DOCKER: adicionar WWWUSER=$(id -u) no .env para evitar arquivos como root")
        fi
    fi

    # Vite
    if [ -f vite.config.js ] || [ -f vite.config.ts ]; then
        gotchas+=("VITE: run 'npm run build' após modificar assets JS/CSS")
    fi

    # DB mismatch
    if [ -f .env ]; then
        if grep -q "DB_CONNECTION=sqlite" .env 2>/dev/null; then
            gotchas+=("DB: .env usa SQLite — verificar se prod usa PostgreSQL")
        fi
        if grep -q "DB_CONNECTION=pgsql" .env 2>/dev/null; then
            gotchas+=("DB: PostgreSQL detectado — verificar se MySQL local é consistente")
        fi
        local db_host
        db_host=$(grep "DB_HOST" .env 2>/dev/null | cut -d'=' -f2 | tr -d ' ' | head -1)
        if [ -n "$db_host" ] && [ "$db_host" != "127.0.0.1" ] && [ "$db_host" != "localhost" ]; then
            gotchas+=("DB: Host remoto detectado: $db_host — verificar conectividade")
        fi
    fi

    # Sail specific
    if [ -f docker-compose.yml ] && grep -q "sail" docker-compose.yml 2>/dev/null; then
        gotchas+=("SAIL: usar 'vendor/bin/sail' em vez de 'docker-compose exec app'")
        gotchas+=("SAIL: prefixo é './vendor/bin/sail' para todos os comandos artisan")
    fi

    # Laravel-specific
    if [ -f artisan ]; then
        gotchas+=("LARAVEL: após 'git pull', verificar se composer.lock mudou — se sim, 'composer install'")
        if grep -q "APP_ENV=production" .env 2>/dev/null; then
            gotchas+=("LARAVEL: APP_ENV=production detectado — debug desabilitado")
        fi
        if [ -f "bootstrap/cache/config.php" ] || [ -d "bootstrap/cache" ]; then
            gotchas+=("LARAVEL: config cacheado — após mudar .env, rodar 'php artisan config:clear'")
        fi
    fi

    # Filament-specific
    if [ -f composer.json ] && grep -q '"filament/filament"' composer.json 2>/dev/null; then
        local filament_version
        filament_version=$(grep '"filament/filament"' composer.json 2>/dev/null | grep -oP '"filament/filament": "\K[^"]+' | head -1)
        # Strip version prefix chars (^ ~ >= etc)
        filament_version="${filament_version#^}"
        filament_version="${filament_version#~}"
        filament_version="${filament_version#>}"
        filament_version="${filament_version#<=}"
        [ -n "$filament_version" ] && gotchas+=("FILAMENT: versão ${filament_version} — v4: RelationManagers diferente, v5: Infolists")
    fi

    # Vite (Laravel 11 default)
    if [ -f vite.config.js ] || [ -f vite.config.ts ]; then
        gotchas+=("VITE: Laravel 11 usa Vite — 'npm run dev' para desenvolvimento, 'npm run build' para produção")
    fi

    # Permissions
    if [ -d storage ] && [ ! -w storage ]; then
        gotchas+=("PERMISSION: diretório storage não gravável — chmod 775 ou usar WWWUSER")
    fi

    # Environment
    if [ -f .env ]; then
        if ! grep -q "APP_ENV=local" .env 2>/dev/null; then
            local app_env
            app_env=$(grep "APP_ENV" .env 2>/dev/null | cut -d'=' -f2 | tr -d ' ' | head -1)
            if [ -n "$app_env" ]; then
                gotchas+=("ENV: APP_ENV=$app_env — verificar se correto para desenvolvimento")
            fi
        fi
    fi

    # Print gotchas
    local result=""
    local g
    for g in "${gotchas[@]}"; do
        result="${result}  - $g\n"
    done
    if [ -z "$result" ]; then
        echo "  (nenhum)"
    else
        echo -e "$result"
    fi
}

# ============================================================
# Main Output
# ============================================================

main() {
    local project
    project=$(get_project_name)

    local stack_output
    stack_output=$(detect_stack)
    local stack
    local runtime
    stack=$(echo "$stack_output" | head -1)
    runtime=$(echo "$stack_output" | grep "^RUNTIME:" | cut -d: -f2-)

    local commands
    commands=$(detect_commands)

    local ports
    ports=$(detect_ports)

    local binaries
    binaries=$(detect_binaries)

    local gotchas
    gotchas=$(detect_gotchas)

    if [ "$MODE" = "json" ]; then
        # Build gotchas JSON array
        local -a gotcha_arr=()
        local gline
        while IFS= read -r gline; do
            [[ "$gline" =~ ^[[:space:]]*-[[:space:]]+(.+)$ ]] && gotcha_arr+=("${BASH_REMATCH[1]}")
        done <<< "$gotchas"

        local gj="[]"
        if [ ${#gotcha_arr[@]} -gt 0 ]; then
            gj='['
            local gi
            for gi in "${gotcha_arr[@]}"; do
                [ "$gj" != "[" ] && gj="$gj," || true
                gj="$gj\"$gi\""
            done
            gj="$gj]"
        fi

        cat << EOF
{
  "project": "$project",
  "stack": "$stack",
  "runtime": "$runtime",
  "commands": "$commands",
  "ports": "$ports",
  "binaries": "$binaries",
  "gotchas": $gj
}
EOF
    else
        cat << EOF

=== DEVORQ ENVIRONMENT CONTEXT ===

Project: $project
Stack: ${stack:-não detectado}
Runtime: ${runtime:-não detectado}
Commands: ${commands:-não detectado}
Ports: $ports
Binaries: ${binaries:-não detectado}

GOTCHAS:
$gotchas

===
EOF
    fi
}

main
