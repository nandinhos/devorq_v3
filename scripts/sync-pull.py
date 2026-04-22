#!/usr/bin/env python3
"""
sync-pull.py — Baixa lessons do HUB PostgreSQL → local (.devorq/state/lessons/)

Uso:
  python3 scripts/sync-pull.py [projeto]

Se projeto não especificado, usa todos.
"""

import subprocess
import json
import os
import sys
import glob as glob_module
from pathlib import Path

# Config
VPS_HOST = os.environ.get("DEVORQ_VPS_HOST", "187.108.197.199")
VPS_PORT = os.environ.get("DEVORQ_VPS_PORT", "6985")
VPS_USER = os.environ.get("DEVORQ_VPS_USER", "root")
PG_DB = os.environ.get("DEVORQ_PG_DB", "hermes_study")
PG_USER = os.environ.get("DEVORQ_PG_USER", "hermes_study")
PG_CONTAINER = os.environ.get("DEVORQ_PG_CONTAINER", "hermesstudy_postgres")
MUX_SOCK = os.environ.get("DEVORQ_MUX_SOCK", "/tmp/devorq-ssh-mux")


def ssh_cmd(cmd, timeout=30):
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
    r = subprocess.run(full, capture_output=True, text=True, timeout=timeout)
    return r.stdout, r.stderr, r.returncode


def pg_query(sql):
    """Executa SQL SELECT e retorna resultado como texto.
    
    Usa json.dumps para escape correto de aspas e caracteres especiais.
    """
    # Escapa todo o SQL via json.dumps (copia o padrao que funciona no sync-push)
    escaped = json.dumps(sql)
    sql_cli = escaped[1:-1]  # Remove aspas externas do json.dumps

    cmd = (
        f"docker exec {PG_CONTAINER} psql -U {PG_USER} -d {PG_DB} "
        f"-t -c \"{sql_cli}\""
    )
    out, err, code = ssh_cmd(cmd)
    return out, err, code


def parse_content_to_problem_solution(content):
    """Divide content do HUB em problem/solution (formato ## Problem / ## Solution)."""
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


def pull_lessons(project_filter=None):
    """Baixa lessons do HUB."""
    project_root = os.environ.get("DEVORQ_PROJECT_ROOT", os.getcwd())
    lessons_dir = os.path.join(project_root, ".devorq", "state", "lessons", "captured")
    downloaded_dir = os.path.join(project_root, ".devorq", "state", "lessons", "downloaded")
    Path(downloaded_dir).mkdir(parents=True, exist_ok=True)

    where = f"WHERE project = '{project_filter}'" if project_filter else ""

    sql = (
        f"SELECT json_agg(json_build_object("
        f"'id', id, "
        f"'title', title, "
        f"'content', content, "
        f"'tags', tags, "
        f"'stack', stack, "
        f"'project', project, "
        f"'source', source, "
        f"'validated_at', validated_at, "
        f"'metadata', metadata, "
        f"'created_at', created_at"
        f")) FROM devorq.lessons {where};"
    )

    out, err, code = pg_query(sql)

    if code != 0 or not out.strip():
        print(f"[!] Erro ao acessar HUB: {err[:100]}")
        return 0

    raw = out.strip()
    if not raw or raw == "null":
        print("[VPS] Nenhuma lesson no HUB")
        return 0

    try:
        lessons = json.loads(raw)
    except json.JSONDecodeError as e:
        print(f"[!] Erro ao parsear resposta: {e}")
        print(f"    Raw: {raw[:200]}")
        return 0

    if not lessons:
        print("[VPS] Nenhuma lesson no HUB")
        return 0

    existing = set()
    for state_dir in [lessons_dir, downloaded_dir]:
        for f in glob_module.glob(os.path.join(state_dir, "*.json")):
            with open(f) as fp:
                try:
                    data = json.load(fp)
                    key = f"{data.get('title', '')}|{data.get('project', '')}"
                    existing.add(key)
                except Exception:
                    pass

    pulled = 0
    for lesson in lessons:
        title = lesson.get("title", "untitled")
        project = lesson.get("project", "devorq_v3")

        key = f"{title}|{project}"
        if key in existing:
            print(f"[~] Ja existe local: {title}")
            continue

        content = lesson.get("content", "")
        problem, solution = parse_content_to_problem_solution(content)

        source_file = ""
        if "## Source" in content:
            source_file = content.split("## Source")[-1].strip()

        stack = lesson.get("stack", [])
        if isinstance(stack, list) and stack:
            stack = stack[0]
        elif not stack:
            stack = "general"

        metadata = lesson.get("metadata") or {}
        if isinstance(metadata, str):
            try:
                metadata = json.loads(metadata)
            except Exception:
                metadata = {}

        local_lesson = {
            "title": title,
            "problem": problem,
            "solution": solution,
            "tags": lesson.get("tags", []),
            "stack": stack,
            "project": project,
            "source_file": source_file,
            "validated": bool(lesson.get("validated_at")),
            "applied": metadata.get("applied", False),
            "recurrence_count": metadata.get("recurrence_count", 0),
            "metadata": metadata
        }

        safe_name = "".join(c if c.isalnum() or c in " -_" else "_" for c in title)[:60]
        filename = f"{safe_name}.json"
        out_path = os.path.join(downloaded_dir, filename)

        with open(out_path, "w") as f:
            json.dump(local_lesson, f, indent=2, ensure_ascii=False)

        print(f"[OK] {title} -> {out_path}")
        pulled += 1

    return pulled


def main():
    project_filter = os.environ.get("DEVORQ_PROJECT_FILTER", None)
    if len(sys.argv) > 1:
        project_filter = sys.argv[1]

    out, err, code = ssh_cmd("echo PING")
    if code != 0:
        print(f"[ERROR] SSH falhou: {err[:200]}")
        sys.exit(1)

    print("[VPS] Baixando lessons do HUB...")
    pulled = pull_lessons(project_filter)
    print(f"[VPS] Sync pull completo: {pulled} lesson(s) baixada(s)")


if __name__ == "__main__":
    main()
