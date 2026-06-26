#!/usr/bin/env python3
"""
sync-pull.py — Baixa lessons do HUB PostgreSQL → local (.devorq/state/lessons/)

SEGURANÇA:
- Validação de paths
- Sanitização de inputs
- SSH com StrictHostKeyChecking
- Exit codes consistentes

Uso:
  python3 scripts/sync-pull.py [projeto]

Se projeto não especificado, usa todos.
"""

import subprocess
import json
import os
import sys
import re
import csv
import io
from pathlib import Path

# Exit codes
EXIT_SUCCESS = 0
EXIT_ERROR = 1
EXIT_INVALID_ARGS = 2
EXIT_NOT_FOUND = 3
EXIT_VALIDATION_FAILED = 4

# Config
VPS_HOST = os.environ.get("DEVORQ_VPS_HOST", "187.108.197.199")
VPS_PORT = os.environ.get("DEVORQ_VPS_PORT", "6985")
VPS_USER = os.environ.get("DEVORQ_VPS_USER", "root")
PG_DB = os.environ.get("DEVORQ_PG_DB", "hermes_study")
PG_USER = os.environ.get("DEVORQ_PG_USER", "hermes_study")
PG_CONTAINER = os.environ.get("DEVORQ_PG_CONTAINER", "hermesstudy_postgres")
MUX_SOCK = os.environ.get("DEVORQ_MUX_SOCK", "/tmp/devorq-ssh-mux")


def ssh_cmd(cmd, timeout=30, input_data=None):
    """Executa comando no VPS via SSH mux com validação de host.

    input_data: se fornecido, e enviado ao STDIN do comando remoto (usado para
    passar SQL ao psql sem o escaping fragil do -c "...").
    """
    Path(MUX_SOCK).parent.mkdir(parents=True, exist_ok=True)

    known_hosts = Path.home() / ".ssh" / "known_hosts"

    full = [
        "ssh",
        "-o", "StrictHostKeyChecking=yes",
        "-o", f"UserKnownHostsFile={known_hosts}",
        "-o", "ControlMaster=auto",
        "-o", f"ControlPath={MUX_SOCK}",
        "-o", "ControlPersist=600",
        "-o", "ConnectTimeout=10",
        "-p", VPS_PORT,
        f"{VPS_USER}@{VPS_HOST}",
        cmd
    ]

    try:
        result = subprocess.run(full, capture_output=True, text=True, timeout=timeout, input=input_data)
        return result.stdout, result.stderr, result.returncode
    except subprocess.TimeoutExpired:
        return "", "Timeout", 1
    except Exception as e:
        return "", str(e), 1


def pg_literal(value):
    """Literal de string PostgreSQL seguro (aspas SIMPLES, escape por duplicacao)."""
    if value is None:
        return "NULL"
    return "'" + str(value).replace("'", "''") + "'"


def pg_query_csv(select_sql):
    """Roda um SELECT e retorna as linhas em CSV via COPY ... TO STDOUT.

    O formato CSV (parseado com o modulo csv) preserva content multiline, pipes
    e aspas — ao contrario do split('\\n')/split('|') anterior, que corrompia
    lessons com newline no content e descartava colunas. SQL enviado por STDIN.
    """
    copy_sql = f"COPY ({select_sql.rstrip(';').strip()}) TO STDOUT WITH (FORMAT csv)"
    cmd = (
        f"docker exec -i {PG_CONTAINER} psql -U {PG_USER} -d {PG_DB} "
        f"-v ON_ERROR_STOP=1 -q"
    )
    out, err, code = ssh_cmd(cmd, input_data=copy_sql)
    return out, err, code


def _parse_pg_array(raw):
    """Parseia um text[] do PostgreSQL ('{a,b,\"c d\"}') para lista Python."""
    if not raw:
        return []
    raw = raw.strip()
    if raw in ("{}", ""):
        return []
    inner = raw.lstrip("{").rstrip("}")
    if not inner:
        return []
    try:
        return [t.strip() for t in next(csv.reader(io.StringIO(inner)))]
    except StopIteration:
        return []


def _row_to_lesson(row):
    """Converte uma linha CSV (id,title,content,tags,stack,project,metadata,created_at)
    em dict de lesson, preservando content multiline e tags."""
    lesson_id, title, content, tags_raw, stack, project, metadata_json = row[:7]
    try:
        metadata = json.loads(metadata_json) if metadata_json else {}
    except (ValueError, TypeError):
        metadata = {}
    problem, solution = parse_content_to_problem_solution(content)
    return {
        "id": lesson_id,
        "title": title,
        "problem": problem,
        "solution": solution,
        "stack": stack or "general",
        "tags": _parse_pg_array(tags_raw),
        "project": project,
        "source": "",
        "validated": bool(metadata.get("applied", False)),
        "applied": bool(metadata.get("applied", False)),
        "recurrence_count": metadata.get("recurrence_count", 0),
        "metadata": metadata,
    }


def parse_content_to_problem_solution(content):
    """Divide content do HUB em problem/solution."""
    if not content:
        return "", ""

    parts = content.split("## Solution")
    problem = ""
    solution = ""

    if len(parts) >= 2:
        problem = parts[0].replace("## Problem", "").strip()
        solution = parts[1].strip()
    else:
        solution = content.strip()

    for section in ["## Source", "## Notes", "## Tags"]:
        if section in solution:
            solution = solution.split(section)[0].strip()

    return problem, solution


def download_lessons(project_filter=None):
    """Baixa lessons do HUB (CSV robusto a content multiline)."""
    where = f"WHERE project = {pg_literal(project_filter)}" if project_filter else ""
    select_sql = (
        "SELECT id, title, content, tags, stack, project, metadata, created_at "
        f"FROM devorq.lessons {where} ORDER BY created_at DESC LIMIT 100"
    )

    out, err, code = pg_query_csv(select_sql)

    if code != 0:
        raise ValueError(f"Query failed: {err}")

    if not out.strip():
        print("[WARN] Nenhuma lesson encontrada")
        return []

    lessons = []
    for row in csv.reader(io.StringIO(out)):
        if len(row) < 7:
            continue
        lessons.append(_row_to_lesson(row))

    return lessons


def save_lessons(lessons, output_dir):
    """Salva lessons baixadas em JSON files."""
    Path(output_dir).mkdir(parents=True, exist_ok=True)
    
    saved = 0
    for lesson in lessons:
        title = lesson["title"]
        safe_id = re.sub(r'[^a-zA-Z0-9_\-]', '_', lesson["id"])
        filename = f"{safe_id}.json"
        filepath = Path(output_dir) / filename
        
        with open(filepath, 'w') as f:
            json.dump(lesson, f, indent=2, ensure_ascii=False)
        
        print(f"[OK] {title}")
        saved += 1
    
    return saved


def main():
    project_filter = None
    if len(sys.argv) > 1:
        project_filter = sys.argv[1]
        if not re.match(r'^[a-zA-Z0-9_\-]+$', project_filter):
            print("[ERROR] Nome de projeto inválido", file=sys.stderr)
            sys.exit(EXIT_INVALID_ARGS)

    project_root = os.environ.get("DEVORQ_PROJECT_ROOT", os.getcwd())
    # Grava em captured/ (lido pelo sistema vivo de licoes), nao em downloaded/
    # (diretorio orfao que nenhum comando lia). DQ-008.
    output_dir = Path(project_root) / ".devorq" / "state" / "lessons" / "captured"
    
    print("[VPS] Baixando lessons <- HUB...")
    out, err, code = ssh_cmd("echo PING")
    if code != 0:
        print(f"[ERROR] SSH failed: {err[:200]}", file=sys.stderr)
        sys.exit(EXIT_ERROR)
    
    try:
        lessons = download_lessons(project_filter)
        if lessons:
            saved = save_lessons(lessons, output_dir)
            print(f"[VPS] Sync pull completo: {saved} lesson(s) baixada(s)")
        else:
            print("[WARN] Nenhuma lesson para baixar")
        sys.exit(EXIT_SUCCESS)
    except ValueError as e:
        print(f"[ERROR] {e}", file=sys.stderr)
        sys.exit(EXIT_VALIDATION_FAILED)
    except Exception as e:
        print(f"[ERROR] Erro inesperado: {e}", file=sys.stderr)
        sys.exit(EXIT_ERROR)


if __name__ == "__main__":
    main()
