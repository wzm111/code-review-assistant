#!/bin/bash
# 命名规范检查
# 检查变量、函数、文件、目录命名是否符合各语言约定

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

TARGET_DIR="${1:-.}"

echo -e "${CYAN}📛 Naming Convention / 命名规范检查${NC}"
echo "=========================================="
echo ""

cd "$TARGET_DIR"

CHANGED_FILES=$(git diff --name-only HEAD~1..HEAD 2>/dev/null || git diff --name-only 2>/dev/null || true)

if [[ -z "$CHANGED_FILES" ]]; then
    echo -e "${YELLOW}无变更文件${NC}"
    exit 0
fi

issues=()
warns=()

# ===== 文件/目录命名检查 =====

echo -e "${CYAN}【文件命名检查】${NC}"
echo ""

while IFS= read -r file; do
    [[ -z "$file" ]] && continue

    # 文件名包含大写字母（除特定扩展名外）
    basename=$(basename "$file")
    dirname=$(dirname "$file")

    # 检查目录名
    if [[ "$dirname" != "." ]]; then
        IFS='/' read -ra dirs <<< "$dirname"
        for d in "${dirs[@]}"; do
            [[ "$d" == "." ]] && continue
            # 目录名含空格
            if [[ "$d" =~ [[:space:]] ]]; then
                warns+=("目录名含空格: $d (建议用 kebab-case 或 snake_case)")
            fi
            # 目录名含大写字母（常见约定用小写）
            if [[ "$d" =~ [A-Z] ]] && [[ "$d" != "__tests__" ]] && [[ "$d" != "__mocks__" ]]; then
                warns+=("目录名含大写: $d (建议全小写)")
            fi
        done
    fi

    # 检查文件名
    name_no_ext="${basename%.*}"
    ext="${basename##*.}"

    # 跳过特定合法大写文件名
    [[ "$name_no_ext" == "README" ]] && continue
    [[ "$name_no_ext" == "LICENSE" ]] && continue
    [[ "$name_no_ext" == "Makefile" ]] && continue
    [[ "$name_no_ext" == "Dockerfile" ]] && continue
    [[ "$name_no_ext" == ".env" ]] && continue
    [[ "$name_no_ext" =~ ^\.[A-Z] ]] && continue  # .Gitignore 等

    # 文件名含空格
    if [[ "$basename" =~ [[:space:]] ]]; then
        issues+=("文件名含空格: $file")
    fi

    # 检查各语言文件的命名
    if [[ "$file" =~ \.(js|ts|jsx|tsx|py|go|php|java|kt|rs|rb)$ ]]; then
        # 源码文件应该用小写 + 连字符或下划线
        if [[ "$name_no_ext" =~ [A-Z] ]]; then
            # Java 类文件允许 PascalCase（与类名一致）
            if [[ ! "$file" =~ \.(java|kt)$ ]]; then
                warns+=("源码文件名含大写: $file (建议 kebab-case 或 snake_case)")
            fi
        fi
    fi

done <<< "$CHANGED_FILES"

if [[ ${#issues[@]} -eq 0 && ${#warns[@]} -eq 0 ]]; then
    echo -e "  ${GREEN}✅ 文件命名检查通过${NC}"
else
    for i in "${issues[@]}"; do
        echo -e "  ${RED}🔴 $i${NC}"
    done
    for w in "${warns[@]}"; do
        echo -e "  ${YELLOW}🟡 $w${NC}"
    done
fi
echo ""

# ===== 变量/函数命名检查（按语言） =====

echo -e "${CYAN}【代码标识符命名检查】${NC}"
echo ""

# 按文件类型分别检查
js_files=$(printf '%s\n' "$CHANGED_FILES" | grep -E '\.(js|ts|jsx|tsx)$' || true)
py_files=$(printf '%s\n' "$CHANGED_FILES" | grep -E '\.py$' || true)
go_files=$(printf '%s\n' "$CHANGED_FILES" | grep -E '\.go$' || true)
java_files=$(printf '%s\n' "$CHANGED_FILES" | grep -E '\.(java|kt)$' || true)
php_files=$(printf '%s\n' "$CHANGED_FILES" | grep -E '\.php$' || true)

# --- JavaScript / TypeScript ---
if [[ -n "$js_files" ]]; then
    echo -e "${CYAN}  JavaScript/TypeScript:${NC}"

    js_issues=()
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        [[ -f "$file" ]] || continue
        content=$(cat "$file" 2>/dev/null || true)
        [[ -z "$content" ]] && continue

        # 变量: const UPPER_SNAKE_CASE 用于常量
        # 警告：const 用小写（除真正的常量）
        while IFS= read -r line; do
            # 检测 const 命名
            if [[ "$line" =~ const[[:space:]]+([a-z][a-zA-Z0-9]*)[[:space:]]*= ]]; then
                name="${BASH_REMATCH[1]}"
                # 跳过常见例外
                [[ "$name" == "config" || "$name" == "options" || "$name" == "props" ]] && continue
                # 如果值是基本类型字面量，应该是 UPPER_SNAKE_CASE
                if [[ "$line" =~ =[[:space:]]*[\"\'0-9] ]]; then
                    if [[ ! "$name" =~ ^[A-Z_]+$ ]]; then
                        js_issues+=("$file: const '$name' 应为 UPPER_SNAKE_CASE (常量)")
                    fi
                fi
            fi

            # 类名应该是 PascalCase
            if [[ "$line" =~ (class|interface)[[:space:]]+([a-z][a-zA-Z0-9]*) ]]; then
                name="${BASH_REMATCH[2]}"
                if [[ ! "$name" =~ ^[A-Z] ]]; then
                    js_issues+=("$file: 类/接口 '$name' 应以大写字母开头 (PascalCase)")
                fi
            fi

            # React 组件应该是 PascalCase
            if [[ "$file" =~ \.(jsx|tsx)$ ]]; then
                # 用 perl 避免 bash [[ =~ ]] 中 ) 的语法问题
                matched=$(printf '%s\n' "$line" | perl -ne 'print "$1\n" if /(?:function|const)\s+([a-z][a-zA-Z0-9]*)\s*(?:\([^)]*\))?\s*\{?\s*(?:return|=>)/')
                if [[ -n "$matched" ]]; then
                    name="$matched"
                    # 如果函数返回 JSX，应该是 PascalCase
                    has_jsx=$(printf '%s\n' "$content" | perl -ne "print 1 if /$name\s*(?:\([^)]*\))?\s*(?:=>|\{)\s*(?:return\s*)?</" | head -c1)
                    if [[ "$has_jsx" == "1" ]]; then
                        if [[ ! "$name" =~ ^[A-Z] ]]; then
                            js_issues+=("$file: React 组件 '$name' 应为 PascalCase")
                        fi
                    fi
                fi
            fi

        done <<< "$content"
    done <<< "$js_files"

    if [[ ${#js_issues[@]} -eq 0 ]]; then
        echo -e "    ${GREEN}✅ 命名规范通过${NC}"
    else
        for i in "${js_issues[@]}"; do
            echo -e "    ${YELLOW}🟡 $i${NC}"
        done
    fi
    echo ""
fi

# --- Python ---
if [[ -n "$py_files" ]]; then
    echo -e "${CYAN}  Python:${NC}"

    py_issues=()
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        [[ -f "$file" ]] || continue
        content=$(cat "$file" 2>/dev/null || true)
        [[ -z "$content" ]] && continue

        while IFS= read -r line; do
            # 类名应该是 PascalCase
            if [[ "$line" =~ ^[[:space:]]*class[[:space:]]+([a-z_][a-zA-Z0-9_]*) ]]; then
                name="${BASH_REMATCH[1]}"
                if [[ ! "$name" =~ ^[A-Z] ]]; then
                    py_issues+=("$file: 类名 '$name' 应为 PascalCase (PEP 8)")
                fi
            fi

            # 函数名应该是 snake_case
            if [[ "$line" =~ ^[[:space:]]*def[[:space:]]+([A-Z][a-zA-Z0-9_]*) ]]; then
                name="${BASH_REMATCH[1]}"
                # 排除 __init__ 等 dunder 方法
                if [[ ! "$name" =~ ^__.*__$ ]]; then
                    py_issues+=("$file: 函数名 '$name' 应为 snake_case (PEP 8)")
                fi
            fi

            # 常量应该是 UPPER_SNAKE_CASE
            if [[ "$line" =~ ^[A-Z][a-zA-Z0-9_]*[[:space:]]*= ]]; then
                name=$(printf '%s\n' "$line" | grep -oE '^[A-Z][a-zA-Z0-9_]*' | head -1 || true)
                if [[ -n "$name" && ! "$name" =~ ^[A-Z_]+$ ]]; then
                    py_issues+=("$file: 常量 '$name' 应为全大写 SNAKE_CASE")
                fi
            fi

            # 单字符变量（循环变量 i/j/k 除外）
            if [[ "$line" =~ \b([a-hl-np-z])\b[[:space:]]*= ]]; then
                var="${BASH_REMATCH[1]}"
                py_issues+=("$file: 单字符变量 '$var' 语义不清 (循环变量 i/j/k 除外)")
            fi
        done <<< "$content"
    done <<< "$py_files"

    if [[ ${#py_issues[@]} -eq 0 ]]; then
        echo -e "    ${GREEN}✅ 命名规范通过${NC}"
    else
        for i in "${py_issues[@]}"; do
            echo -e "    ${YELLOW}🟡 $i${NC}"
        done
    fi
    echo ""
fi

# --- Go ---
if [[ -n "$go_files" ]]; then
    echo -e "${CYAN}  Go:${NC}"

    go_issues=()
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        [[ -f "$file" ]] || continue
        content=$(cat "$file" 2>/dev/null || true)
        [[ -z "$content" ]] && continue

        while IFS= read -r line; do
            # 导出函数/变量应为 PascalCase
            if [[ "$line" =~ ^[[:space:]]*(func|var|const|type)[[:space:]]+([a-z][a-zA-Z0-9_]*)[[:space:]]*(\(|=|struct|interface)? ]]; then
                name="${BASH_REMATCH[2]}"
                # 如果首字母小写但被导出使用，可能是命名不当
                # 简化：只检查明显问题
                if [[ "$name" =~ _ ]]; then
                    go_issues+=("$file: Go 标识符 '$name' 不应使用下划线 (Go 惯例用驼峰)")
                fi
            fi

            # 包名检查
            if [[ "$line" =~ ^package[[:space:]]+([A-Z]) ]]; then
                pkg="${BASH_REMATCH[1]}"
                go_issues+=("$file: 包名 '$pkg...' 应全小写")
            fi
        done <<< "$content"
    done <<< "$go_files"

    if [[ ${#go_issues[@]} -eq 0 ]]; then
        echo -e "    ${GREEN}✅ 命名规范通过${NC}"
    else
        for i in "${go_issues[@]}"; do
            echo -e "    ${YELLOW}🟡 $i${NC}"
        done
    fi
    echo ""
fi

# --- Java / Kotlin ---
if [[ -n "$java_files" ]]; then
    echo -e "${CYAN}  Java/Kotlin:${NC}"

    java_issues=()
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        [[ -f "$file" ]] || continue
        content=$(cat "$file" 2>/dev/null || true)
        [[ -z "$content" ]] && continue

        while IFS= read -r line; do
            # 类名/接口名应为 PascalCase
            if [[ "$line" =~ (class|interface|enum)[[:space:]]+([a-z][a-zA-Z0-9_]*) ]]; then
                name="${BASH_REMATCH[2]}"
                if [[ ! "$name" =~ ^[A-Z] ]]; then
                    java_issues+=("$file: 类/接口 '$name' 应为 PascalCase")
                fi
            fi

            # 方法名应为 camelCase
            if [[ "$line" =~ (public|private|protected|static|final|abstract|void|boolean|int|String|List|Map|Set|Optional)[[:space:]]+([A-Z][a-zA-Z0-9_]*)[[:space:]]*\( ]]; then
                name="${BASH_REMATCH[2]}"
                # 排除类名（构造函数）
                if [[ ! "$content" =~ class[[:space:]]+$name ]]; then
                    java_issues+=("$file: 方法 '$name' 应为 camelCase")
                fi
            fi

            # 常量应为 UPPER_SNAKE_CASE
            if [[ "$line" =~ (public|private|protected)[[:space:]]+static[[:space:]]+final[[:space:]]+.*[[:space:]]+([a-z][a-zA-Z0-9_]*)[[:space:]]*= ]]; then
                name="${BASH_REMATCH[2]}"
                if [[ ! "$name" =~ ^[A-Z_] ]]; then
                    java_issues+=("$file: 常量 '$name' 应为 UPPER_SNAKE_CASE")
                fi
            fi
        done <<< "$content"
    done <<< "$java_files"

    if [[ ${#java_issues[@]} -eq 0 ]]; then
        echo -e "    ${GREEN}✅ 命名规范通过${NC}"
    else
        for i in "${java_issues[@]}"; do
            echo -e "    ${YELLOW}🟡 $i${NC}"
        done
    fi
    echo ""
fi

# --- PHP ---
if [[ -n "$php_files" ]]; then
    echo -e "${CYAN}  PHP:${NC}"

    php_issues=()
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        [[ -f "$file" ]] || continue
        content=$(cat "$file" 2>/dev/null || true)
        [[ -z "$content" ]] && continue

        while IFS= read -r line; do
            # 类名应为 PascalCase (PSR-12)
            if [[ "$line" =~ (class|interface|trait)[[:space:]]+([a-z][a-zA-Z0-9_]*) ]]; then
                name="${BASH_REMATCH[2]}"
                if [[ ! "$name" =~ ^[A-Z] ]]; then
                    php_issues+=("$file: 类/接口 '$name' 应为 PascalCase (PSR-12)")
                fi
            fi

            # 方法名应为 camelCase (PSR-12)
            if [[ "$line" =~ (public|private|protected|static|function)[[:space:]]+([A-Z][a-zA-Z0-9_]*)[[:space:]]*\( ]]; then
                name="${BASH_REMATCH[2]}"
                # 排除魔术方法
                if [[ ! "$name" =~ ^__.*__$ ]]; then
                    php_issues+=("$file: 方法 '$name' 应为 camelCase (PSR-12)")
                fi
            fi

            # 常量应为 UPPER_SNAKE_CASE (PSR-12)
            if [[ "$line" =~ (const)[[:space:]]+([a-z][a-zA-Z0-9_]*)[[:space:]]*= ]]; then
                name="${BASH_REMATCH[2]}"
                if [[ ! "$name" =~ ^[A-Z_] ]]; then
                    php_issues+=("$file: 常量 '$name' 应为 UPPER_SNAKE_CASE (PSR-12)")
                fi
            fi
        done <<< "$content"
    done <<< "$php_files"

    if [[ ${#php_issues[@]} -eq 0 ]]; then
        echo -e "    ${GREEN}✅ 命名规范通过${NC}"
    else
        for i in "${php_issues[@]}"; do
            echo -e "    ${YELLOW}🟡 $i${NC}"
        done
    fi
    echo ""
fi

# ===== 总结 =====

echo -e "${CYAN}【命名规范最佳实践】${NC}"
echo "  JavaScript/TypeScript:"
echo "    变量/函数: camelCase         例: getUserName, fetchData"
echo "    类/接口:   PascalCase        例: UserService, ApiClient"
echo "    常量:      UPPER_SNAKE_CASE  例: MAX_RETRY, API_BASE_URL"
echo "    文件:      kebab-case        例: user-service.ts"
echo ""
echo "  Python:"
echo "    变量/函数: snake_case        例: get_user_name, fetch_data"
echo "    类:        PascalCase        例: UserService"
echo "    常量:      UPPER_SNAKE_CASE  例: MAX_RETRY"
echo "    文件:      snake_case        例: user_service.py"
echo ""
echo "  Go:"
echo "    变量/函数: camelCase         例: getUserName (导出: GetUserName)"
echo "    包名:      全小写             例: userservice"
echo "    文件:      snake_case        例: user_service.go"
echo "    常量:      同变量            例: maxRetry (导出: MaxRetry)"
echo ""
echo "  Java/Kotlin:"
echo "    变量/方法: camelCase         例: getUserName, userList"
echo "    类:        PascalCase        例: UserService"
echo "    常量:      UPPER_SNAKE_CASE  例: MAX_RETRY"
echo "    文件:      与类名一致         例: UserService.java"
echo ""
echo "  PHP (PSR-12):"
echo "    变量/方法: camelCase         例: getUserName"
echo "    类:        PascalCase        例: UserService"
echo "    常量:      UPPER_SNAKE_CASE  例: MAX_RETRY"
echo ""
echo "  通用文件命名:"
echo "    目录:      全小写/kebab-case 例: src/utils, src/user-service"
echo "    文件:      不含空格、不含大写 (除特定文件如 README)"
echo "    测试:      *.test.* 或 *.spec.*"
