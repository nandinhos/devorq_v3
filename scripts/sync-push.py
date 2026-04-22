#!/usr/bin/env python3
"""
sync-push.py — Sincroniza lessons locais → HUB PostgreSQL (VPS)

Uso:
  python3 scripts/sync-push.py [diretorio_lessons]

Requer:
  - SSH acesso ao VPS (mesmo ambiente que lib/vps.sh)
  -psycopg2 NO VPS (ou usa json + psql via docker exec)
"""

import subprocess
import json
import os
import sys
import glob
from pathlib import Path

# Config (igual lib/vps.sh)
VPS_HOST = os.environ.get("DEVORQ_VPS_HOST", "187.108.197.199")
VPS_PORT = os.environ.get("DEVORQ_VPS_PORT", "6985")
VPS_USER = os.environ.get("DEVORQ_VPS_USER", "root")
PG_DB = os.environ.get("DEVORQ_PG_DB", "hermes_study")
PG_USER = os.environ.get("DEVORQ_PG_USER", "hermes_study")
PG_CONTAINER = os.environ.get("DEVORQ_PG_CONTAINER", "hermesstudy_postgres")
MUX_SOCK = os.environ.get("DEVORQ_MUX_SOCK", "/tmp/devorq-ssh-mux")


def ssh_cmd(cmd, timeout=30):
    """Executa comando no VPS via SSH mux."""
    Path(MUX_SOCK).parent.mkdir(parents=True, exist_ok=True)

    full = [
        "ssh", "-o", "ControlMaster=auto",
        "-o", f"ControlPath={MUX_SOCK}",
        "-o", "ControlPersist=600",
        "-o", "StrictHostKeyChecking=accept-new",
        "-o", "ConnectTimeout=10",
        "-p", VPS_PORT,
        f"{VPS_USER}@{VPS_HOST}",
        cmd
    ]
    result = subprocess.run(full, capture_output=True, text=True, timeout=timeout)
    return result.stdout, result.stderr, result.returncode


def pg_exec(sql, fetch=False):
    """Executa SQL no PostgreSQL do HUB via docker exec.
    
    Usa json.dumps para escape seguro — evita SQL injection.
    """
    # Serializa o SQL com json.dumps para escape correto de todos os caracteres
    # inclusive apostrofos, newlines, backslashes, etc.
    sql_json = json.dumps(sql)

    # Remove aspas externas do json.dumps (json.dumps retorna '"..."')
    sql_escaped = sql_json[1:-1]

    cmd = (
        f"docker exec {PG_CONTAINER} psql -U {PG_USER} -d {PG_DB} "
        f"-c \"{sql_escaped}\""
    )
    out, err, code = ssh_cmd(cmd)

    if code != 0 and err:
        # Tenta com E'' string se houve erro de escaping
        sql_e = sql.replace("'", "''")
        cmd2 = (
            f"docker exec {PG_CONTAINER} psql -U {PG_USER} -d {PG_DB} "
            f"-c 'SELECT 1' 2>/dev/null"  # teste conexão
        )
        out2, _, _ = ssh_cmd(cmd2)
        if out2:
            # Fallback: usa escape com E''
            cmd3 = (
                f"docker exec {PG_CONTAINER} psql -U {PG_USER} -d {PG_DB} "
                f"-c \"E'{sql_e}'\""
            )
            out, err, code = ssh_cmd(cmd3)

    if fetch:
        return out, err, code
    return code == 0


def load_lesson(path):
    """Carrega lesson de um JSON file."""
    with open(path) as f:
        return json.load(f)


def sync_lessons(lessons_dir, project_filter=None):
    """Sincroniza todos os JSONs de lessons."""
    patterns = glob.glob(os.path.join(lessons_dir, "*.json"))
    if not patterns:
        print("[!] Nenhuma lesson encontrada")
        return 0

    print(f"[VPS] {len(patterns)} lesson(s) encontrada(s)")

    synced = 0
    for path in sorted(patterns):
        lesson = load_lesson(path)

        title = lesson.get("title", "untitled")
        problem = lesson.get("problem", "")
        solution = lesson.get("solution", "")
        tags = lesson.get("tags", [])
        stack = lesson.get("stack", "general")
        project = lesson.get("project", "devorq_v3")
        source_file = lesson.get("source_file", "")
        validated = lesson.get("validated", False)
        applied = lesson.get("applied", False)
        recurrence_count = lesson.get("recurrence_count", 0)
        metadata = lesson.get("metadata", {})

        # Skip se project filter definido
        if project_filter and project != project_filter:
            continue

        # Combina problem + solution em content (formato padrão HUB)
        content = f"## Problem\n{problem}\n\n## Solution\n{solution}"
        if source_file:
            content += f"\n\n## Source\n{source_file}"

        # Serializa tags como PostgreSQL text[] array
        if tags:
            tags_sql = "ARRAY[" + ", ".join(json.dumps(t) for t in tags) + "]::text[]"
        else:
            tags_sql = "'{}'::text[]"

        # stack e metadata vao no metadata JSONB
        metadata = lesson.get("metadata", {})
        metadata["applied"] = applied
        metadata["recurrence_count"] = recurrence_count
        metadata_json = json.dumps(metadata)

        # validated_at = now() se validated=true
        validated_at = "now()" if validated else "NULL"

        # Verifica se lesson com mesmo title+project já existe
        check_sql = (
            f"SELECT id FROM devorq.lessons "
            f"WHERE title = {json.dumps(title)} "
            f"AND project = {json.dumps(project)} LIMIT 1;"
        )
        out, _, code = pg_exec(check_sql, fetch=True)

        if code == 0 and out and "1 row" in out:
            print(f"[~] Ja existe: {title} (pulando)")
            continue

        # INSERT — só colunas que existem no schema real do HUB
        # stack=text, tags=text[], validated_at=timestamp, metadata=jsonb
        insert_sql = (
            f"INSERT INTO devorq.lessons "
            f"(title, content, tags, stack, project, source, validated_at, metadata, created_at) "
            f"VALUES ("
            f"{json.dumps(title)}, "
            f"{json.dumps(content)}, "
            f"{tags_sql}, "
            f"{json.dumps(stack) if stack else 'NULL'}, "
            f"{json.dumps(project)}, "
            f"{json.dumps(source_file) if source_file else 'NULL'}, "
            f"{validated_at}, "
            f"{json.dumps(metadata_json)}, "
            f"now()"
            f");"
        )

        code = pg_exec(insert_sql)

        if code == 0:
            print(f"[OK] {title}")
            synced += 1
        else:
            print(f"[!] Falhou: {title}")

    return synced


def main():
    project_root = os.environ.get("DEVORQ_PROJECT_ROOT", os.getcwd())
    lessons_dir = os.path.join(project_root, ".devorq", "state", "lessons", "captured")
    project_filter = os.environ.get("DEVORQ_PROJECT_FILTER", None)

    if len(sys.argv) > 1:
        lessons_dir = sys.argv[1]

    if not os.path.isdir(lessons_dir):
        print(f"[!] Diretorio nao encontrado: {lessons_dir}")
        sys.exit(1)

    # Testa conexao
    print(f"[VPS] Sincronizando lessons -> HUB...")
    out, err, code = ssh_cmd("echo PING")
    if code != 0:
        print(f"[ERROR] SSH falhou: {err[:200]}")
        sys.exit(1)

    synced = sync_lessons(lessons_dir, project_filter)
    print(f"[VPS] Sync push completo: {synced} lesson(s) sincronizada(s)")


if __name__ == "__main__":
    main()
