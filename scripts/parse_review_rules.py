#!/usr/bin/env python3
"""
Lightweight YAML parser for .review-rules.yml.
Supports the subset used by code-review-assistant:
  - top-level sections: version, disable, custom_rules, behavior, languages
  - lists: - item
  - objects under custom_rules: - id: ... followed by key: value pairs
  - arrays: key: [a, b, c]
  - block scalars: key: | or key: > with indented continuation lines
PyYAML is preferred when available; this module is a pure-Python fallback.
"""

import json
import sys


def parse_scalar(value: str):
    """Parse a YAML scalar value into a Python object."""
    value = value.strip()
    if not value:
        return ""

    # Array literal: [a, b, c]
    if value.startswith("[") and value.endswith("]"):
        inner = value[1:-1]
        if not inner.strip():
            return []
        return [parse_scalar(part) for part in inner.split(",") if part.strip()]

    # Quoted string
    if (value.startswith('"') and value.endswith('"')) or (
        value.startswith("'") and value.endswith("'")
    ):
        return value[1:-1]

    # Booleans
    low = value.lower()
    if low == "true":
        return True
    if low == "false":
        return False

    # Integer
    if value.isdigit() or (value.startswith("-") and value[1:].isdigit()):
        return int(value)

    # Plain string
    return value


def get_indent(line: str) -> int:
    return len(line) - len(line.lstrip())


def parse_block_scalar(lines, start_index: int, base_indent: int):
    """
    Parse a block scalar (| or >) starting at lines[start_index].
    Returns (value, next_index).
    """
    i = start_index + 1
    content_lines = []
    while i < len(lines):
        line = lines[i]
        if not line.strip() or line.strip().startswith("#"):
            i += 1
            continue
        indent = get_indent(line)
        if indent <= base_indent:
            break
        # Strip the extra indentation relative to the key line
        content_lines.append(line[base_indent + 2 :].rstrip("\n"))
        i += 1
    return "\n".join(content_lines), i


def parse_yaml_simple(text: str) -> dict:
    data = {
        "version": "",
        "disable": [],
        "custom_rules": [],
        "behavior": {},
        "languages": {},
    }
    lines = text.splitlines()
    i = 0
    n = len(lines)

    while i < n:
        line = lines[i]
        if not line.strip() or line.strip().startswith("#"):
            i += 1
            continue

        indent = get_indent(line)
        stripped = line.strip()

        # Top-level keys/sections: version, disable, custom_rules, behavior, languages
        # Allow a small leading indentation to tolerate common manual editing mistakes.
        if indent <= 2 and ":" in stripped and not stripped.startswith("-"):
            key, value = stripped.split(":", 1)
            key = key.strip()
            value = value.strip()

            if value == "|" or value == ">":
                block_value, i = parse_block_scalar(lines, i, indent)
                data[key] = block_value
                continue

            if key in ("disable", "custom_rules", "behavior", "languages"):
                section_key = key
                section_indent = indent
                i += 1
                while i < n:
                    line = lines[i]
                    if not line.strip() or line.strip().startswith("#"):
                        i += 1
                        continue
                    inner_indent = get_indent(line)
                    inner_stripped = line.strip()

                    if inner_indent <= section_indent and not inner_stripped.startswith("-"):
                        break

                    if section_key == "disable":
                        if inner_stripped.startswith("-"):
                            data["disable"].append(parse_scalar(inner_stripped[1:]))
                        i += 1

                    elif section_key == "behavior":
                        if ":" in inner_stripped:
                            k, v = inner_stripped.split(":", 1)
                            k = k.strip()
                            v = v.strip()
                            if v in ("|", ">"):
                                block_value, i = parse_block_scalar(lines, i, inner_indent)
                                data["behavior"][k] = block_value
                                continue
                            if not v:
                                # Possibly a nested list (e.g. exclude_patterns:)
                                next_i = i + 1
                                list_values = []
                                while next_i < n:
                                    line = lines[next_i]
                                    if not line.strip() or line.strip().startswith("#"):
                                        next_i += 1
                                        continue
                                    ni = get_indent(line)
                                    if ni <= inner_indent:
                                        break
                                    ns = line.strip()
                                    if ns.startswith("-"):
                                        list_values.append(parse_scalar(ns[1:]))
                                        next_i += 1
                                    else:
                                        break
                                if list_values:
                                    data["behavior"][k] = list_values
                                    i = next_i
                                    continue
                            data["behavior"][k] = parse_scalar(v)
                        i += 1

                    elif section_key == "custom_rules":
                        if inner_stripped.startswith("-"):
                            rule = {}
                            first = inner_stripped[1:].strip()
                            if ":" in first:
                                k, v = first.split(":", 1)
                                rule[k.strip()] = parse_scalar(v)
                            i += 1
                            while i < n:
                                line = lines[i]
                                if not line.strip() or line.strip().startswith("#"):
                                    i += 1
                                    continue
                                next_indent = get_indent(line)
                                if next_indent <= inner_indent:
                                    break
                                next_stripped = line.strip()
                                if ":" in next_stripped:
                                    k, v = next_stripped.split(":", 1)
                                    k = k.strip()
                                    v = v.strip()
                                    if v in ("|", ">"):
                                        block_value, i = parse_block_scalar(lines, i, next_indent)
                                        rule[k] = block_value
                                        continue
                                    rule[k] = parse_scalar(v)
                                i += 1
                            data["custom_rules"].append(rule)
                        else:
                            i += 1

                    elif section_key == "languages":
                        # languages:
                        #   java:
                        #     custom_rules: [...]
                        #     behavior: {...}
                        if inner_indent == 2 and inner_stripped.endswith(":"):
                            lang = inner_stripped[:-1].strip()
                            data["languages"][lang] = {"custom_rules": [], "behavior": {}}
                            i += 1
                            while i < n:
                                line = lines[i]
                                if not line.strip() or line.strip().startswith("#"):
                                    i += 1
                                    continue
                                lang_indent = get_indent(line)
                                lang_stripped = line.strip()
                                if lang_indent <= inner_indent:
                                    break
                                if lang_stripped == "custom_rules:":
                                    i += 1
                                    while i < n:
                                        line = lines[i]
                                        if not line.strip() or line.strip().startswith("#"):
                                            i += 1
                                            continue
                                        ri = get_indent(line)
                                        rs = line.strip()
                                        if ri <= lang_indent:
                                            break
                                        if rs.startswith("-"):
                                            rule = {}
                                            first = rs[1:].strip()
                                            if ":" in first:
                                                k, v = first.split(":", 1)
                                                rule[k.strip()] = parse_scalar(v)
                                            i += 1
                                            while i < n:
                                                line = lines[i]
                                                if not line.strip() or line.strip().startswith("#"):
                                                    i += 1
                                                    continue
                                                ni = get_indent(line)
                                                if ni <= ri:
                                                    break
                                                ns = line.strip()
                                                if ":" in ns:
                                                    k, v = ns.split(":", 1)
                                                    k = k.strip()
                                                    v = v.strip()
                                                    if v in ("|", ">"):
                                                        block_value, i = parse_block_scalar(lines, i, ni)
                                                        rule[k] = block_value
                                                        continue
                                                    rule[k] = parse_scalar(v)
                                                i += 1
                                            data["languages"][lang]["custom_rules"].append(rule)
                                        else:
                                            i += 1
                                elif lang_stripped == "behavior:":
                                    i += 1
                                    while i < n:
                                        line = lines[i]
                                        if not line.strip() or line.strip().startswith("#"):
                                            i += 1
                                            continue
                                        bi = get_indent(line)
                                        bs = line.strip()
                                        if bi <= lang_indent:
                                            break
                                        if ":" in bs:
                                            k, v = bs.split(":", 1)
                                            k = k.strip()
                                            v = v.strip()
                                            if v in ("|", ">"):
                                                block_value, i = parse_block_scalar(lines, i, bi)
                                                data["languages"][lang]["behavior"][k] = block_value
                                                continue
                                            data["languages"][lang]["behavior"][k] = parse_scalar(v)
                                        i += 1
                                else:
                                    i += 1
                        else:
                            i += 1
                    else:
                        i += 1
                continue
            else:
                data[key] = parse_scalar(value)
                i += 1
                continue

        i += 1

    return data


def main():
    if len(sys.argv) < 2:
        print(json.dumps({"disable": [], "custom_rules": [], "behavior": {}, "languages": {}}, ensure_ascii=False))
        sys.exit(0)

    file_path = sys.argv[1]
    try:
        import yaml

        with open(file_path, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f) or {}
        # Normalize shape
        result = {
            "version": data.get("version", ""),
            "disable": data.get("disable", []),
            "custom_rules": data.get("custom_rules", []),
            "behavior": data.get("behavior", {}),
            "languages": data.get("languages", {}),
        }
        print(json.dumps(result, ensure_ascii=False))
        return
    except Exception:
        pass

    try:
        with open(file_path, "r", encoding="utf-8") as f:
            text = f.read()
        result = parse_yaml_simple(text)
        print(json.dumps(result, ensure_ascii=False))
    except Exception as e:
        print(json.dumps({"disable": [], "custom_rules": [], "behavior": {}, "languages": {}, "error": str(e)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
