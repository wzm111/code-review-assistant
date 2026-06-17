#!/usr/bin/env python3
"""Unit tests for scripts/parse_review_rules.py."""

import io
import json
import os
import sys
import tempfile
import unittest

# Add ../scripts to path so we can import the parser module.
SCRIPT_DIR = os.path.join(os.path.dirname(__file__), "..", "scripts")
sys.path.insert(0, SCRIPT_DIR)

import parse_review_rules as parser  # noqa: E402


class TestParseYamlSimple(unittest.TestCase):
    """Tests for the pure-Python fallback YAML parser."""

    def test_empty_and_minimal(self):
        result = parser.parse_yaml_simple("")
        self.assertEqual(result["disable"], [])
        self.assertEqual(result["custom_rules"], [])
        self.assertEqual(result["behavior"], {})
        self.assertEqual(result["languages"], {})

    def test_disable_list(self):
        yaml_text = """
disable:
  - "frontend:react-hooks-exhaustive-deps"
  - 'java:try-with-resources'
  - python:mutable-default-args
"""
        result = parser.parse_yaml_simple(yaml_text)
        self.assertEqual(
            result["disable"],
            [
                "frontend:react-hooks-exhaustive-deps",
                "java:try-with-resources",
                "python:mutable-default-args",
            ],
        )

    def test_custom_rules(self):
        yaml_text = """
custom_rules:
  - id: "project:no-raw-sql"
    category: "Architecture"
    severity: "critical"
    languages: ["java", "php"]
    message: "No raw SQL in controllers"
    check: "Flag SQL strings"
"""
        result = parser.parse_yaml_simple(yaml_text)
        self.assertEqual(len(result["custom_rules"]), 1)
        rule = result["custom_rules"][0]
        self.assertEqual(rule["id"], "project:no-raw-sql")
        self.assertEqual(rule["category"], "Architecture")
        self.assertEqual(rule["severity"], "critical")
        self.assertEqual(rule["languages"], ["java", "php"])
        self.assertEqual(rule["message"], "No raw SQL in controllers")
        self.assertEqual(rule["check"], "Flag SQL strings")

    def test_behavior(self):
        yaml_text = """
behavior:
  max_function_lines: 40
  exclude_patterns:
    - "**/*.generated.ts"
    - "**/vendor/**"
"""
        result = parser.parse_yaml_simple(yaml_text)
        self.assertEqual(result["behavior"]["max_function_lines"], 40)
        self.assertEqual(
            result["behavior"]["exclude_patterns"],
            ["**/*.generated.ts", "**/vendor/**"],
        )

    def test_project_context_block_scalar(self):
        yaml_text = """
behavior:
  project_context: |
    This is line one.
    This is line two.
  max_function_lines: 50
"""
        result = parser.parse_yaml_simple(yaml_text)
        self.assertEqual(
            result["behavior"]["project_context"],
            "This is line one.\nThis is line two.",
        )
        self.assertEqual(result["behavior"]["max_function_lines"], 50)

    def test_languages(self):
        yaml_text = """
languages:
  java:
    custom_rules:
      - id: "project:java-no-lombok-data"
        category: "Maintainability"
        severity: "suggestion"
        message: "Avoid @Data in JPA entities"
    behavior:
      max_function_lines: 40
  python:
    behavior:
      max_function_lines: 30
"""
        result = parser.parse_yaml_simple(yaml_text)
        self.assertIn("java", result["languages"])
        self.assertIn("python", result["languages"])
        java_rules = result["languages"]["java"]["custom_rules"]
        self.assertEqual(len(java_rules), 1)
        self.assertEqual(java_rules[0]["id"], "project:java-no-lombok-data")
        self.assertEqual(
            result["languages"]["java"]["behavior"]["max_function_lines"], 40
        )
        self.assertEqual(
            result["languages"]["python"]["behavior"]["max_function_lines"], 30
        )

    def test_scalar_types(self):
        yaml_text = """
behavior:
  bool_true: true
  bool_false: false
  int_val: 42
  negative_int: -7
  quoted_str: "hello"
  single_quoted_str: 'world'
  array_literal: [a, b, c]
"""
        result = parser.parse_yaml_simple(yaml_text)
        behavior = result["behavior"]
        self.assertEqual(behavior["bool_true"], True)
        self.assertEqual(behavior["bool_false"], False)
        self.assertEqual(behavior["int_val"], 42)
        self.assertEqual(behavior["negative_int"], -7)
        self.assertEqual(behavior["quoted_str"], "hello")
        self.assertEqual(behavior["single_quoted_str"], "world")
        self.assertEqual(behavior["array_literal"], ["a", "b", "c"])

    def test_comments_and_blank_lines_ignored(self):
        yaml_text = """
# This is a comment
version: "1.0"

# Another comment
disable:
  - "rule:one"
"""
        result = parser.parse_yaml_simple(yaml_text)
        self.assertEqual(result["version"], "1.0")
        self.assertEqual(result["disable"], ["rule:one"])


class TestMain(unittest.TestCase):
    """Tests for parse_review_rules.py main() entry point."""

    def _write_temp_file(self, content):
        fd, path = tempfile.mkstemp(suffix=".yml")
        os.write(fd, content.encode("utf-8"))
        os.close(fd)
        return path

    def test_main_parses_file(self):
        yaml_text = """
disable:
  - "frontend:react-hooks-exhaustive-deps"
behavior:
  max_function_lines: 60
"""
        path = self._write_temp_file(yaml_text)
        old_stdout = sys.stdout
        old_argv = sys.argv
        try:
            sys.stdout = io.StringIO()
            sys.argv = ["parse_review_rules.py", path]
            parser.main()
            output = sys.stdout.getvalue()
        finally:
            sys.stdout = old_stdout
            sys.argv = old_argv
            os.unlink(path)

        data = json.loads(output)
        self.assertEqual(data["disable"], ["frontend:react-hooks-exhaustive-deps"])
        self.assertEqual(data["behavior"]["max_function_lines"], 60)

    def test_main_no_arguments(self):
        old_stdout = sys.stdout
        old_argv = sys.argv
        try:
            sys.stdout = io.StringIO()
            sys.argv = ["parse_review_rules.py"]
            try:
                parser.main()
            except SystemExit as e:
                self.assertEqual(e.code, 0)
            output = sys.stdout.getvalue()
        finally:
            sys.stdout = old_stdout
            sys.argv = old_argv

        data = json.loads(output)
        self.assertEqual(data["disable"], [])
        self.assertEqual(data["custom_rules"], [])
        self.assertEqual(data["behavior"], {})
        self.assertEqual(data["languages"], {})


class TestExampleFile(unittest.TestCase):
    """Test that the bundled example file parses correctly."""

    def test_example_file(self):
        repo_root = os.path.join(os.path.dirname(__file__), "..")
        example_path = os.path.join(repo_root, ".review-rules.yml.example")
        if not os.path.exists(example_path):
            self.skipTest("example file not found")

        # Run via subprocess to exercise the CLI entry point.
        import subprocess

        result = subprocess.run(
            [sys.executable, os.path.join(SCRIPT_DIR, "parse_review_rules.py"), example_path],
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, msg=result.stderr)
        data = json.loads(result.stdout)
        self.assertEqual(data["version"], "1.0")
        self.assertEqual(
            data["disable"],
            [
                "frontend:react-hooks-exhaustive-deps",
                "python:mutable-default-args",
                "security:owasp-a06-cve",
            ],
        )
        self.assertEqual(len(data["custom_rules"]), 3)
        self.assertEqual(data["behavior"]["max_function_lines"], 50)
        self.assertEqual(
            data["behavior"]["exclude_patterns"],
            ["**/*.generated.ts", "**/vendor/**", "**/migrations/*.sql", "**/*.test.ts"],
        )
        self.assertIn("java", data["languages"])
        self.assertIn("python", data["languages"])


if __name__ == "__main__":
    unittest.main()
