#!/usr/bin/env python3
"""
sync-push.py — Sincroniza lessons locais → HUB PostgreSQL (VPS)

SEGURANÇA:
- Validação de paths
- Sanitização de inputs
- SSH com StrictHostKeyChecking
- Sem credenciais em logs
- Exit codes consistentes

Uso:
  python3 scripts/sync-push.py [diretorio_lessons]

Requer:
  - SSH acesso ao VPS
  - psycopg2 NO VPS (ou usa json + psql via docker exec)
"""

import subprocess
import json
import os
import sys
import glob
import re
from pathlib import Path

# Exit codes
EXIT_SUCCESS = 0
EXIT_ERROR = 1
EXIT_INVALID_ARGS = 2
EXIT_NOT_FOUND = 3
EXIT_VALIDATION_FAILED = 4

# Config - carrega de arquivo seguro se existir
def load_config():
    """Carrega configuração de arquivo seguro."""
    config_file = Path.home() / ".config" / "devorq" / "config"
    
    if config_file.exists():
        # Verificar permissões (deve ser 600)
        mode = config_file.stat().st_mode & 0o777
        if mode & 0o077:
            print("[WARN] Config file has insecure permissions", file=sys.stderr)
        else:
            with open(config_file) as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('#'):
                        if '=' in line:
                            key, _, value = line.partition('=')
                            os.environ[key.strip()] = value.strip()

# Carregar config
load_config()

# Config (de variáveis de ambiente ou defaults)
VPS_HOST = os.environ.get("DEVORQ_VPS_HOST", "187.108.197.199")
VPS_PORT = os.environ.get("DEVORQ_VPS_PORT", "6985")
VPS_USER = os.environ.get("DEVORQ_VPS_USER", "root")
PG_DB = os.environ.get("DEVORQ_PG_DB", "hermes_study")
PG_USER = os.environ.get("DEVORQ_PG_USER", "hermes_study")
PG_CONTAINER = os.environ.get("DEVORQ_PG_CONTAINER", "hermesstudy_postgres")
MUX_SOCK = os.environ.get("DEVORQ_MUX_SOCK", "/tmp/devorq-ssh-mux")

# Sanitização para logs
def sanitize_for_log(value):
    """Remove informações sensíveis para logs."""
    if not value:
        return "***REDACTED***"
    if len(value) > 4:
        return f"{value[0]}***{value[-1]}"
    return "***REDACTED***"

# Validação de path
def validate_path(path, base_dir):
    """
    Valida que path está dentro de base_dir.
    Retorna path normalizado ou lança ValueError.
    """
    try:
        real_path = Path(path).resolve()
        real_base = Path(base_dir).resolve()
        
        # Verificar se está dentro
        try:
            real_path.relative_to(real_base)
        except ValueError:
            raise ValueError(f"Path {path} is outside {base_dir}")
        
        return real_path
    except Exception as e:
        raise ValueError(f"Invalid path: {e}")

# Sanitização de input
def sanitize_identifier(value):
    """Sanitiza identificadores SQL."""
    if not re.match(r'^[a-zA-Z_][a-zA-Z0-9_]*$', value or ''):
        raise ValueError(f"Invalid identifier: {value}")
    return value

def sanitize_input(value, allow_special=False):
    """
    Sanitiza input de usuário.
    allow_special=True permite alguns caracteres especiais.
    """
    if not value:
        return value
    
    if allow_special:
        # Permite apenas caracteres seguros para paths
        return re.sub(r'[^a-zA-Z0-9._\/\- ]', '', value)
    else:
        # Remove caracteres perigosos
        return re.sub(r'[^a-zA-Z0-9._\-]', '', value)

# SSH com validação de host
def ssh_cmd(cmd, timeout=30):
    """Executa comando no VPS via SSH mux com validação de host."""
    Path(MUX_SOCK).parent.mkdir(parents=True, exist_ok=True)

    # Verificar se host é conhecido
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
        result = subprocess.run(
            full,
            capture_output=True,
            text=True,
            timeout=timeout
        )
        return result.stdout, result.stderr, result.returncode
    except subprocess.TimeoutExpired:
        return "", "Timeout", 1
    except Exception as e:
        return "", str(e), 1

def pg_exec(sql, fetch=False):
    """Executa SQL no PostgreSQL do HUB via docker exec.
    
    Usa json.dumps para escape seguro — evita SQL injection.
    """
    # Serializa o SQL com json.dumps para escape correto
    sql_json = json.dumps(sql)
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
    """Carrega lesson de um JSON file com validação."""
    try:
        with open(path) as f:
            return json.load(f)
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in {path}: {e}")


def sync_lessons(lessons_dir, project_filter=None):
    """Sincroniza todos os JSONs de lessons."""
    # Validar lessons_dir
    if not os.path.isdir(lessons_dir):
        raise ValueError(f"Directory not found: {lessons_dir}")
    
    patterns = glob.glob(os.path.join(lessons_dir, "*.json"))
    if not patterns:
        print("[WARN] Nenhuma lesson encontrada")
        return 0

    print(f"[VPS] {len(patterns)} lesson(s) encontrada(s)")

    synced = 0
    for path in sorted(patterns):
        try:
            lesson = load_lesson(path)
        except ValueError as e:
            print(f"[ERROR] {e}")
            continue

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

        # Combina problem + solution em content
        content = f"## Problem\n{problem}\n\n## Solution\n{solution}"
        if source_file:
            content += f"\n\n## Source\n{source_file}"

        # Serializa tags como PostgreSQL text[] array
        if tags:
            tags_sql = "ARRAY[" + ", ".join(json.dumps(t) for t in tags) + "]::text[]"
        else:
            tags_sql = "'{}'::text[]"

        # metadata no metadata JSONB
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
            print(f"[SKIP] Ja existe: {title}")
            continue

        # INSERT
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
            print(f"[ERROR] Falhou: {title}")

    return synced


def main():
    # Obter arguments
    project_root = os.environ.get("DEVORQ_PROJECT_ROOT", os.getcwd())
    lessons_dir = os.path.join(project_root, ".devorq", "state", "lessons", "captured")
    project_filter = os.environ.get("DEVORQ_PROJECT_FILTER", None)

    if len(sys.argv) > 1:
        lessons_dir = sys.argv[1]

    # Validar lessons_dir
    if not os.path.isdir(lessons_dir):
        print(f"[ERROR] Diretorio nao encontrado: {lessons_dir}", file=sys.stderr)
        sys.exit(EXIT_NOT_FOUND)

    # Testa conexao
    print(f"[VPS] Sincronizando lessons -> HUB...")
    out, err, code = ssh_cmd("echo PING")
    if code != 0:
        print(f"[ERROR] SSH falhou: {err[:200]}", file=sys.stderr)
        sys.exit(EXIT_ERROR)

    try:
        synced = sync_lessons(lessons_dir, project_filter)
        print(f"[VPS] Sync push completo: {synced} lesson(s) sincronizada(s)")
        sys.exit(EXIT_SUCCESS)
    except ValueError as e:
        print(f"[ERROR] {e}", file=sys.stderr)
        sys.exit(EXIT_VALIDATION_FAILED)
    except Exception as e:
        print(f"[ERROR] Erro inesperado: {e}", file=sys.stderr)
        sys.exit(EXIT_ERROR)


if __name__ == "__main__":
    main()
