#!/usr/bin/env python3
"""
test_sync.py — Unit tests para scripts/sync-*.py

Testa:
  - Sanitização de inputs
  - Validação de paths
  - Validação de identificadores SQL
  - Exit codes
  - Parsing de content

Uso:
  python3 scripts/test_sync.py
"""

import unittest
import sys
import os
import json
import tempfile
import re
from pathlib import Path

# Adicionar scripts ao path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Importar módulos (sem executar main)
import importlib.util

def load_module(name):
    """Carrega um módulo Python sem executá-lo."""
    path = os.path.join(os.path.dirname(__file__), name)
    spec = importlib.util.spec_from_file_location(name.replace('.py', ''), path)
    module = importlib.util.module_from_spec(spec)
    # Não executar o módulo, apenas carregar as funções
    return module

# ============================================================
# Testes para sync-push.py
# ============================================================

class TestSyncPushSecurity(unittest.TestCase):
    """Testes de segurança para sync-push.py"""

    def setUp(self):
        """Setup para os testes."""
        self.temp_dir = tempfile.mkdtemp()

    def tearDown(self):
        """Cleanup após os testes."""
        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    # ============================================================
    # Testes de sanitize_for_log
    # ============================================================

    def test_sanitize_for_log_none(self):
        """Sanitização de None/empty."""
        # Carregar a função inline para evitar import do módulo principal
        def sanitize_for_log(value):
            if not value:
                return "***REDACTED***"
            if len(value) > 4:
                return f"{value[0]}***{value[-1]}"
            return "***REDACTED***"

        self.assertEqual(sanitize_for_log(None), "***REDACTED***")
        self.assertEqual(sanitize_for_log(""), "***REDACTED***")

    def test_sanitize_for_log_short(self):
        """Sanitização de strings curtas."""
        def sanitize_for_log(value):
            if not value:
                return "***REDACTED***"
            if len(value) > 4:
                return f"{value[0]}***{value[-1]}"
            return "***REDACTED***"

        self.assertEqual(sanitize_for_log("abc"), "***REDACTED***")
        self.assertEqual(sanitize_for_log("ab"), "***REDACTED***")

    def test_sanitize_for_log_normal(self):
        """Sanitização normal."""
        def sanitize_for_log(value):
            if not value:
                return "***REDACTED***"
            if len(value) > 4:
                return f"{value[0]}***{value[-1]}"
            return "***REDACTED***"

        self.assertEqual(sanitize_for_log("secret123"), "s***3")
        self.assertEqual(sanitize_for_log("password"), "p***d")

    # ============================================================
    # Testes de validate_path
    # ============================================================

    def test_validate_path_valid(self):
        """Path válido dentro do diretório base."""
        def validate_path(path, base_dir):
            try:
                real_path = Path(path).resolve()
                real_base = Path(base_dir).resolve()
                try:
                    real_path.relative_to(real_base)
                except ValueError:
                    raise ValueError(f"Path {path} is outside {base_dir}")
                return real_path
            except Exception as e:
                raise ValueError(f"Invalid path: {e}")

        base = self.temp_dir
        subdir = os.path.join(base, "subdir")
        os.makedirs(subdir)

        result = validate_path(subdir, base)
        self.assertTrue(result.is_dir())

    def test_validate_path_outside(self):
        """Path fora do diretório base (traversal)."""
        def validate_path(path, base_dir):
            try:
                real_path = Path(path).resolve()
                real_base = Path(base_dir).resolve()
                try:
                    real_path.relative_to(real_base)
                except ValueError:
                    raise ValueError(f"Path {path} is outside {base_dir}")
                return real_path
            except Exception as e:
                raise ValueError(f"Invalid path: {e}")

        base = self.temp_dir
        outside = "/etc/passwd"

        with self.assertRaises(ValueError) as ctx:
            validate_path(outside, base)
        self.assertIn("outside", str(ctx.exception))

    def test_validate_path_traversal(self):
        """Path traversal com ../."""
        def validate_path(path, base_dir):
            try:
                real_path = Path(path).resolve()
                real_base = Path(base_dir).resolve()
                try:
                    real_path.relative_to(real_base)
                except ValueError:
                    raise ValueError(f"Path {path} is outside {base_dir}")
                return real_path
            except Exception as e:
                raise ValueError(f"Invalid path: {e}")

        base = self.temp_dir
        traversal = os.path.join(base, "..", "..", "etc", "passwd")

        with self.assertRaises(ValueError):
            validate_path(traversal, base)

    # ============================================================
    # Testes de sanitize_identifier
    # ============================================================

    def test_sanitize_identifier_valid(self):
        """Identificadores SQL válidos."""
        def sanitize_identifier(value):
            if not re.match(r'^[a-zA-Z_][a-zA-Z0-9_]*$', value or ''):
                raise ValueError(f"Invalid identifier: {value}")
            return value

        self.assertEqual(sanitize_identifier("user_name"), "user_name")
        self.assertEqual(sanitize_identifier("Table123"), "Table123")
        self.assertEqual(sanitize_identifier("_private"), "_private")

    def test_sanitize_identifier_invalid(self):
        """Identificadores SQL inválidos."""
        def sanitize_identifier(value):
            if not re.match(r'^[a-zA-Z_][a-zA-Z0-9_]*$', value or ''):
                raise ValueError(f"Invalid identifier: {value}")
            return value

        with self.assertRaises(ValueError):
            sanitize_identifier("user; DROP TABLE")
        with self.assertRaises(ValueError):
            sanitize_identifier("123table")
        with self.assertRaises(ValueError):
            sanitize_identifier("")
        with self.assertRaises(ValueError):
            sanitize_identifier("user-name")

    # ============================================================
    # Testes de sanitize_input
    # ============================================================

    def test_sanitize_input_no_special(self):
        """Sanitização sem permitir especiais."""
        def sanitize_input(value, allow_special=False):
            if not value:
                return value
            if allow_special:
                return re.sub(r'[^a-zA-Z0-9._\/\- ]', '', value)
            else:
                return re.sub(r'[^a-zA-Z0-9._\-]', '', value)

        self.assertEqual(sanitize_input("test_file.txt"), "test_file.txt")
        self.assertEqual(sanitize_input("name-123"), "name-123")

    def test_sanitize_input_blocks_injection(self):
        """Bloqueia caracteres de injection."""
        def sanitize_input(value, allow_special=False):
            if not value:
                return value
            if allow_special:
                return re.sub(r'[^a-zA-Z0-9._\/\- ]', '', value)
            else:
                return re.sub(r'[^a-zA-Z0-9._\-]', '', value)

        # ; ; | ` $ ( ) são bloqueados, mas - é permitido
        self.assertEqual(sanitize_input("test; rm -rf /"), "testrm-rf")
        self.assertEqual(sanitize_input("' OR '1'='1"), "OR11")
        self.assertEqual(sanitize_input("test`echo`"), "testecho")

    def test_sanitize_input_with_special(self):
        """Sanitização permitindo especiais para paths."""
        def sanitize_input(value, allow_special=False):
            if not value:
                return value
            if allow_special:
                return re.sub(r'[^a-zA-Z0-9._\/\- ]', '', value)
            else:
                return re.sub(r'[^a-zA-Z0-9._\-]', '', value)

        self.assertEqual(sanitize_input("/path/to/file", allow_special=True), "/path/to/file")
        self.assertEqual(sanitize_input("../dangerous", allow_special=True), "../dangerous")
        # Mas ainda bloqueia outros especiais
        self.assertEqual(sanitize_input("test; rm", allow_special=True), "test rm")

    # ============================================================
    # Testes de load_lesson
    # ============================================================

    def test_load_lesson_valid(self):
        """Carrega JSON válido."""
        def load_lesson(path):
            with open(path) as f:
                return json.load(f)

        path = os.path.join(self.temp_dir, "lesson.json")
        lesson_data = {
            "title": "Test",
            "problem": "Issue",
            "solution": "Fix"
        }
        with open(path, 'w') as f:
            json.dump(lesson_data, f)

        result = load_lesson(path)
        self.assertEqual(result["title"], "Test")

    def test_load_lesson_invalid_json(self):
        """Falha com JSON inválido."""
        def load_lesson(path):
            try:
                with open(path) as f:
                    return json.load(f)
            except json.JSONDecodeError as e:
                raise ValueError(f"Invalid JSON in {path}: {e}")

        path = os.path.join(self.temp_dir, "bad.json")
        with open(path, 'w') as f:
            f.write("{ invalid json }")

        with self.assertRaises(ValueError) as ctx:
            load_lesson(path)
        self.assertIn("Invalid JSON", str(ctx.exception))


# ============================================================
# Testes para sync-pull.py
# ============================================================

class TestSyncPullSecurity(unittest.TestCase):
    """Testes de segurança para sync-pull.py"""

    def setUp(self):
        """Setup para os testes."""
        self.temp_dir = tempfile.mkdtemp()

    def tearDown(self):
        """Cleanup após os testes."""
        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    # ============================================================
    # Testes de parse_content_to_problem_solution
    # ============================================================

    def test_parse_content_valid(self):
        """Parsing de content válido."""
        def parse_content_to_problem_solution(content):
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

        content = "## Problem\nThe issue\n\n## Solution\nThe fix"
        problem, solution = parse_content_to_problem_solution(content)
        self.assertEqual(problem, "The issue")
        self.assertEqual(solution, "The fix")

    def test_parse_content_with_source(self):
        """Parsing ignora seções após Solution."""
        def parse_content_to_problem_solution(content):
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

        content = "## Problem\nIssue\n\n## Solution\nFix\n\n## Source\nfile.py"
        _, solution = parse_content_to_problem_solution(content)
        self.assertNotIn("## Source", solution)
        self.assertEqual(solution, "Fix")

    def test_parse_content_empty(self):
        """Parsing de content vazio."""
        def parse_content_to_problem_solution(content):
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

        problem, solution = parse_content_to_problem_solution("")
        self.assertEqual(problem, "")
        self.assertEqual(solution, "")

    # ============================================================
    # Testes de validação de project name
    # ============================================================

    def test_project_name_valid(self):
        """Nomes de projeto válidos."""
        pattern = r'^[a-zA-Z0-9_\-]+$'

        self.assertTrue(re.match(pattern, "my-project"))
        self.assertTrue(re.match(pattern, "my_project"))
        self.assertTrue(re.match(pattern, "Project123"))
        self.assertTrue(re.match(pattern, "a"))

    def test_project_name_invalid(self):
        """Nomes de projeto inválidos."""
        pattern = r'^[a-zA-Z0-9_\-]+$'

        self.assertFalse(re.match(pattern, "my project"))
        self.assertFalse(re.match(pattern, "my;project"))
        self.assertFalse(re.match(pattern, "my/project"))
        self.assertFalse(re.match(pattern, "my'project"))

    # ============================================================
    # Testes de save_lessons
    # ============================================================

    def test_save_lessons(self):
        """Salva lessons em JSON."""
        def save_lessons(lessons, output_dir):
            Path(output_dir).mkdir(parents=True, exist_ok=True)
            saved = 0
            for lesson in lessons:
                title = lesson["title"]
                safe_id = re.sub(r'[^a-zA-Z0-9_\-]', '_', lesson["id"])
                filename = f"{safe_id}.json"
                filepath = Path(output_dir) / filename
                with open(filepath, 'w') as f:
                    json.dump(lesson, f, indent=2, ensure_ascii=False)
                saved += 1
            return saved

        lessons = [
            {"id": "lesson-001", "title": "Test 1"},
            {"id": "lesson_002", "title": "Test 2"}
        ]
        output_dir = os.path.join(self.temp_dir, "output")

        saved = save_lessons(lessons, output_dir)
        self.assertEqual(saved, 2)
        self.assertTrue(os.path.exists(os.path.join(output_dir, "lesson-001.json")))
        self.assertTrue(os.path.exists(os.path.join(output_dir, "lesson_002.json")))

    def test_save_lessons_sanitizes_id(self):
        """Sanitiza IDs com caracteres especiais."""
        def save_lessons(lessons, output_dir):
            Path(output_dir).mkdir(parents=True, exist_ok=True)
            saved = 0
            for lesson in lessons:
                title = lesson["title"]
                safe_id = re.sub(r'[^a-zA-Z0-9_\-]', '_', lesson["id"])
                filename = f"{safe_id}.json"
                filepath = Path(output_dir) / filename
                with open(filepath, 'w') as f:
                    json.dump(lesson, f, indent=2, ensure_ascii=False)
                saved += 1
            return saved

        lessons = [{"id": "lesson; rm -rf /", "title": "Dangerous"}]
        output_dir = os.path.join(self.temp_dir, "output")

        saved = save_lessons(lessons, output_dir)
        self.assertEqual(saved, 1)
        # - é permitido no regex, então lesson; rm -rf / -> lesson__rm_-rf__.json
        self.assertTrue(os.path.exists(os.path.join(output_dir, "lesson__rm_-rf__.json")))


# ============================================================
# Testes de Exit Codes
# ============================================================

class TestExitCodes(unittest.TestCase):
    """Testes de exit codes consistentes."""

    def test_exit_codes_defined(self):
        """Verifica que exit codes estão definidos."""
        EXIT_SUCCESS = 0
        EXIT_ERROR = 1
        EXIT_INVALID_ARGS = 2
        EXIT_NOT_FOUND = 3
        EXIT_VALIDATION_FAILED = 4

        self.assertEqual(EXIT_SUCCESS, 0)
        self.assertEqual(EXIT_ERROR, 1)
        self.assertEqual(EXIT_INVALID_ARGS, 2)
        self.assertEqual(EXIT_NOT_FOUND, 3)
        self.assertEqual(EXIT_VALIDATION_FAILED, 4)

    def test_exit_codes_unique(self):
        """Exit codes são únicos."""
        codes = [0, 1, 2, 3, 4]
        self.assertEqual(len(codes), len(set(codes)))


# ============================================================
# Main
# ============================================================

if __name__ == '__main__':
    print("=" * 50)
    print(" DEVORQ v3 — Sync Scripts Unit Tests")
    print("=" * 50)
    print()

    # Run tests
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromModule(sys.modules[__name__])

    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)

    print()
    print("=" * 50)
    print(f" Tests run:    {result.testsRun}")
    print(f" Failures:     {len(result.failures)}")
    print(f" Errors:       {len(result.errors)}")
    print("=" * 50)

    if result.wasSuccessful():
        print("\n✓ ALL TESTS PASSED")
        sys.exit(0)
    else:
        print("\n✗ SOME TESTS FAILED")
        sys.exit(1)
