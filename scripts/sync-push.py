#!/usr/bin/env python3
"""
sync-push.py — Sincroniza lessons locais → HUB PostgreSQL

Uso:
  python3 scripts/sync-push.py [diretorio_lessons]

Requer:
  - SSH acesso ao VPS (mesmo ambiente que lib/vps.sh)
  - ~bin/jq disponível
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
MUX_SOCK = os.environ.get("DEVORQ_MUX_SOCK", "/tmp/devorq-ssh-mux")


def ssh_cmd(cmd):
    """Executa comando no VPS via SSH mux."""
    # Garante dir do mux
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
    result = subprocess.run(full, capture_output=True, text=True)
    return result.stdout, result.stderr, result.returncode


def pg_exec(sql):
    """Executa SQL no PostgreSQL do HUB."""
    # Escape simples para shell — usa psycopg2-like approach via psql
    escaped_sql = sql.replace("'", "'\"'\"'")
    cmd = f"docker exec hermesstudy_postgres psql -U {PG_USER} -d {PG_DB} -c '{escaped_sql}'"
    out, err, code = ssh_cmd(cmd)
    return out, err, code


def load_lesson(path):
    """Carrega lesson de um JSON file."""
    with open(path) as f:
        return json.load(f)


def sync_lessons(lessons_dir):
    """Sincroniza todos os JSONs de lessons."""
    patterns = glob.glob(os.path.join(lessons_dir, "*.json"))
    if not patterns:
        print("[!] Nenhuma lesson encontrada")
        return

    print(f"[VPS] {len(patterns)} lesson(s) encontrada(s)")

    for path in patterns:
        lesson = load_lesson(path)

        title = lesson.get("title", "untitled")
        problem = lesson.get("problem", "")
        solution = lesson.get("solution", "")
        tags = lesson.get("tags", [])
        stack = lesson.get("stack", "unknown")
        project = lesson.get("project", "devorq_v3")

        # Combina problem + solution em content
        content = f"Problem: {problem} | Solution: {solution}"

        # Serializa arrays
        tags_str = "ARRAY[" + ", ".join(f"'{t}'" for t in tags) + "]" if tags else "ARRAY[]::text[]"
        stack_str = "ARRAY[" + ", ".join(f"'{s}'" for s in [stack]) + "]" if stack else "ARRAY[]::text[]"

        sql = f"INSERT INTO devorq.lessons (title, content, tags, stack, project, created_at) VALUES ('{title}', E'{content}', {tags_str}, {stack_str}, '{project}', now())"

        out, err, code = pg_exec(sql)

        if code == 0:
            print(f"[OK] {title}")
        else:
            print(f"[!] Falhou: {title}")
            print(f"    {err[:100]}")


def main():
    project_root = os.environ.get("DEVORQ_PROJECT_ROOT", os.getcwd())
    lessons_dir = os.path.join(project_root, ".devorq", "state", "lessons", "captured")

    if len(sys.argv) > 1:
        lessons_dir = sys.argv[1]

    if not os.path.isdir(lessons_dir):
        print(f"[!] Diretório não encontrado: {lessons_dir}")
        sys.exit(1)

    # Testa conexão
    print(f"[VPS] Sincronizando lessons → HUB...")
    out, err, code = ssh_cmd("echo PING")
    if code != 0:
        print(f"[ERROR] SSH falhou: {err}")
        sys.exit(1)

    sync_lessons(lessons_dir)
    print("[VPS] Sync push completo")


if __name__ == "__main__":
    main()
