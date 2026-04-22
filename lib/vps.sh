#!/usr/bin/env bash
# lib/vps.sh — VPS HUB connectivity + sync
#
# SSH multiplexing para conexões rápidas (~0.3s/comando)
# Sincroniza .devorq/state/lessons ↔ PostgreSQL devorq.lessons

set -euo pipefail

VPS_HOST="${DEVORQ_VPS_HOST:-187.108.197.199}"
VPS_PORT="${DEVORQ_VPS_PORT:-6985}"
VPS_USER="${DEVORQ_VPS_USER:-root}"

PG_DB="${DEVORQ_PG_DB:-hermes_study}"
PG_USER="${DEVORQ_PG_USER:-hermes_study}"
PG_PORT="${DEVORQ_PG_PORT:-5433}"

MUX_SOCK="${DEVORQ_MUX_SOCK:-/tmp/devorq-ssh-mux}"

# ============================================================
# check — Testa conexão com VPS HUB
# ============================================================

vps::check() {
    echo "[VPS] Testando ${VPS_HOST}:${VPS_PORT}..."

    if ! command -v ssh &>/dev/null; then
        echo "[ERROR] ssh não encontrado"
        return 1
    fi

    mkdir -p "$(dirname "$MUX_SOCK")"

    local result
    result=$(ssh -o "ControlMaster=auto" \
             -o "ControlPath=${MUX_SOCK}" \
             -o "ControlPersist=600" \
             -o "StrictHostKeyChecking=accept-new" \
             -o "ConnectTimeout=5" \
             -p "$VPS_PORT" \
             "${VPS_USER}@${VPS_HOST}" \
             "echo PING" 2>&1) || {
        echo "[ERROR] SSH falhou: $result"
        return 1
    }

    if echo "$result" | grep -q "PING"; then
        echo "[OK] VPS responde"
    else
        echo "[ERROR] Resposta inesperada: $result"
        return 1
    fi
}

# ============================================================
# exec — Executa comando no VPS via SSH mux
# ============================================================

vps::exec() {
    local cmd="$*"
    [ -z "$cmd" ] && echo "Uso: vps::exec <comando>" && return 1

    ssh -o "ControlMaster=auto" \
        -o "ControlPath=${MUX_SOCK}" \
        -o "ControlPersist=600" \
        -o "StrictHostKeyChecking=accept-new" \
        -o "ConnectTimeout=10" \
        -p "$VPS_PORT" \
        "${VPS_USER}@${VPS_HOST}" \
        "$cmd"
}

# ============================================================
# pg_exec — Executa SQL no PostgreSQL do HUB
# ============================================================

vps::pg_exec() {
    local sql="$*"
    [ -z "$sql" ] && echo "Uso: vps::pg_exec <sql>" && return 1

    # Usa printf %q para escapar correctamente
    local escaped
    escaped=$(printf '%s' "$sql" | sed "s/'/'\"'\"'/g")

    vps::exec "docker exec hermesstudy_postgres psql -U ${PG_USER} -d ${PG_DB} -c '${escaped}'"
}

# ============================================================
# lessons_count — Conta lições no HUB
# ============================================================

vps::lessons_count() {
    vps::pg_exec "SELECT count(*) FROM devorq.lessons;" 2>/dev/null || echo "0"
}

# ============================================================
# sync_push — Envia lessons locais → HUB PostgreSQL
# ============================================================

vps::sync_push() {
    local project_root="${PWD}"
    local lessons_dir="${project_root}/.devorq/state/lessons/captured"

    if [ ! -d "$lessons_dir" ]; then
        echo "[!] Nenhuma lesson local para sincronizar"
        return 0
    fi

    mkdir -p "$(dirname "$MUX_SOCK")"

    echo "[VPS] Sincronizando lessons → HUB..."
    local count=$(ls "$lessons_dir"/*.json 2>/dev/null | wc -l)
    echo "[VPS] $count lesson(s) encontrada(s)"

    for f in "$lessons_dir"/*.json; do
        [ -f "$f" ] || continue

        local title problem solution tags stack project
        if command -v jq &>/dev/null; then
            title=$(jq -r '.title' "$f" 2>/dev/null || echo "")
            problem=$(jq -r '.problem' "$f" 2>/dev/null || echo "")
            solution=$(jq -r '.solution' "$f" 2>/dev/null || echo "")
            tags=$(jq -c '.tags // []' "$f" 2>/dev/null || echo "[]")
            stack=$(jq -c '.stack // []' "$f" 2>/dev/null || echo "[]")
            project=$(jq -r '.project // "devorq_v3"' "$f" 2>/dev/null || echo "devorq_v3")
        else
            # Fallback grep
            title=$(grep -o "\"title\"[[:space:]]*:[[:space:]]*\"[^\"]*" "$f" | head -1 | sed 's/.*: "//;s/"$//')
            problem=$(grep -o "\"problem\"[[:space:]]*:[[:space:]]*\"[^\"]*" "$f" | head -1 | sed 's/.*: "//;s/"$//')
            solution=$(grep -o "\"solution\"[[:space:]]*:[[:space:]]*\"[^\"]*" "$f" | head -1 | sed 's/.*: "//;s/"$//')
            tags="[]"; stack="[]"; project="devorq_v3"
        fi

        # Escape simples para SQL
        title="${title//\'/\'\'}"
        problem="${problem//\'/\'\'}"
        solution="${solution//\'/\'\'}"
        project="${project:-devorq_v3}"
        stack="${stack:-unknown}"
        tags="${tags:-[]}"

        # Garante que stack é string SQL válida
        stack="'${stack}'"
        tags="'${tags}'"

        # Escape via Python (confiável para SQL)
        content="Problem: ${problem} | Solution: ${solution}"
        escaped_content=$(python3 -c "import sys,json; print(json.dumps(sys.stdin.read().rstrip('\n'))[1:-1])" <<< "$content")

        local sql="INSERT INTO devorq.lessons (title, content, tags, stack, project, created_at) VALUES ('${title}', E'${escaped_content}', '${tags}', '${stack}', '${project}', now())"

        if vps::pg_exec "$sql" >/dev/null 2>&1; then
            echo "[OK] $title"
        else
            echo "[!] Falhou: $title"
        fi
    done

    echo "[VPS] Sync push completo"
}

# ============================================================
# sync_pull — Recebe lessons do HUB → local
# ============================================================

vps::sync_pull() {
    local project_root="${PWD}"
    local lessons_dir="${project_root}/.devorq/state/lessons/captured"

    mkdir -p "$lessons_dir"

    echo "[VPS] Sincronizando lessons ← HUB..."

    local lessons_json
    lessons_json=$(vps::pg_exec "SELECT json_agg(json_build_object('title', title, 'problem', problem, 'solution', solution, 'tags', tags, 'stack', stack, 'project', project, 'created_at', created_at)) FROM devorq.lessons;" 2>/dev/null) || {
        echo "[!] Não foi possível acessar o HUB"
        return 1
    }

    if [ -z "$lessons_json" ] || [ "$lessons_json" = "null" ]; then
        echo "[!] Nenhuma lesson no HUB"
        return 0
    fi

    echo "[OK] HUB possui lessons"
    echo "[VPS] Sync pull completo (implícito via dev-memory-laravel UI)"
}
