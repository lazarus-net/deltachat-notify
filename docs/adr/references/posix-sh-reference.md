# POSIX sh Reference Guide

Author: vld.lazar@proton.me
Generated/edited with Claude
Copyright: vld.lazar@proton.me
Related: ADR #0012

## POSIX sh Alternatives Reference

This table documents POSIX-compliant alternatives to common bash features:

| Feature | Bash Syntax | POSIX sh Alternative | Notes |
|---------|-------------|---------------------|-------|
| **Shebang** | `#!/bin/bash` | `#!/bin/sh` | Use system's POSIX shell |
| **Strict mode** | `set -euo pipefail` | `set -eu` | pipefail is bash-only; omit or handle manually |
| **Field separator** | `IFS=$'\n\t'` | `IFS='<newline><tab>'` | Use literal newline/tab characters |
| **Extended test** | `[[ -n "$var" ]]` | `[ -n "$var" ]` | Single brackets are POSIX |
| **Pattern matching** | `[[ "$x" == pattern* ]]` | `case "$x" in pattern*) ... esac` | Use case statements |
| **Regex matching** | `[[ "$x" =~ regex ]]` | `echo "$x" \| grep -E 'regex'` | Use external grep |
| **String contains** | `[[ "$x" == *substr* ]]` | `case "$x" in *substr*) ... esac` | Use case or grep |
| **Logical operators** | `[[ $a && $b ]]` | `[ "$a" ] && [ "$b" ]` | Separate test commands |
| **Arithmetic** | `(( i++ ))` | `i=$((i + 1))` | POSIX arithmetic expansion |
| **Arithmetic test** | `(( i > 5 ))` | `[ "$i" -gt 5 ]` | Use test operators |
| **Echo with escapes** | `echo -e "foo\nbar"` | `printf "foo\nbar\n"` | printf is POSIX, echo -e is not |
| **Colored output** | `echo -e "${RED}text${NC}"` | `printf "${RED}%s${NC}\n" "text"` | Use printf for formatting |
| **Arrays** | `arr=(a b c)` | Use positional params or files | Arrays are bash-only |
| **Array access** | `${arr[0]}` | `set -- a b c; echo "$1"` | Use positional parameters |
| **String length** | `${#var}` | `expr length "$var"` | Or `awk 'BEGIN{print length(ARGV[1])}' "$var"` |
| **String substitution** | `${var//old/new}` | `echo "$var" \| sed 's/old/new/g'` | Use sed for substitution |
| **Substring** | `${var:0:5}` | `echo "$var" \| cut -c1-5` | Use cut or awk |
| **Default value** | `${var:-default}` | `${var:-default}` | This IS POSIX |
| **Command substitution** | `$(command)` | `$(command)` or \`command\` | Both are POSIX |
| **Process substitution** | `<(command)` | Use temporary files | Process substitution is bash-only |
| **Here-string** | `<<< "$var"` | `printf '%s\n' "$var" \| cmd` | Use printf and pipe |
| **Readline** | `read -p "Prompt: " var` | `printf "Prompt: "; read var` | Separate prompt from read |
| **Silent read** | `read -s password` | `stty -echo; read password; stty echo` | Use stty for hiding input |
| **Read timeout** | `read -t 5 var` | Requires external timeout command | -t is not POSIX |
| **Read array** | `read -a arr <<< "$line"` | Use set: `set -- $line` | No native arrays in POSIX sh |
| **For loop (C-style)** | `for ((i=0; i<5; i++))` | `i=0; while [ $i -lt 5 ]; do ... i=$((i+1)); done` | Use while loop |
| **For loop (range)** | `for i in {1..10}` | `i=1; while [ $i -le 10 ]; do ... i=$((i+1)); done` | Brace expansion is bash-only |
| **Function return** | `return $value` | `return $value` | POSIX (but only 0-255) |
| **Local variables** | `local var=value` | `var=value` | local is not POSIX (use carefully) |
| **Source script** | `source script.sh` | `. script.sh` | Use dot command |
| **Associative arrays** | `declare -A map` | Not available | Use separate variables or external tools |
| **Export function** | `export -f funcname` | Not supported | Functions can't be exported in POSIX |
| **Declare types** | `declare -i num=5` | `num=5` | No type declarations in POSIX |
| **Nameref** | `declare -n ref=var` | Not supported | No name references in POSIX |
| **Read from fd** | `read -u 3 var` | `read var <&3` | Use input redirection |
| **Test existence** | `[[ -e file ]]` | `[ -e file ]` | Single bracket works |
| **Test not** | `[[ ! -f file ]]` | `[ ! -f file ]` | Single bracket works |
| **Compound test** | `[[ $a && $b ]]` | `[ "$a" -a "$b" ]` | Or use separate: `[ "$a" ] && [ "$b" ]` |
| **Null command** | `:` | `:` | Colon is POSIX |
| **While read loop** | `while IFS= read -r line` | `while IFS= read -r line` | This IS POSIX |
| **Command success** | `if command; then` | `if command; then` | POSIX |
| **Exit status** | `$?` | `$?` | POSIX |
| **Background jobs** | `command &` | `command &` | POSIX |
| **Pipe status** | `${PIPESTATUS[@]}` | Not available | Check each command separately |
| **Trap** | `trap 'cmd' EXIT` | `trap 'cmd' EXIT` | POSIX (EXIT, INT, TERM, etc.) |
| **Arithmetic operators** | `$(( a + b ))` | `$(( a + b ))` | POSIX supports: + - * / % |
| **Comparison operators** | `-eq -ne -lt -le -gt -ge` | `-eq -ne -lt -le -gt -ge` | All POSIX |
| **String operators** | `= != -z -n` | `= != -z -n` | All POSIX |
| **File tests** | `-f -d -e -r -w -x -s` | `-f -d -e -r -w -x -s` | All POSIX |

## Examples

### Example 1: Colored Output

**Before (bash):**
```bash
#!/bin/bash
RED='\033[0;31m'
NC='\033[0m'
echo -e "${RED}Error:${NC} Something failed"
```

**After (POSIX sh):**
```sh
#!/bin/sh
RED='\033[0;31m'
NC='\033[0m'
printf "${RED}Error:${NC} %s\n" "Something failed"
```

### Example 2: Argument Parsing

**Before (bash):**
```bash
#!/bin/bash
while [[ $# -gt 0 ]]; do
    case $1 in
        --force) FORCE=1; shift ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done
```

**After (POSIX sh):**
```sh
#!/bin/sh
while [ $# -gt 0 ]; do
    case $1 in
        --force) FORCE=1; shift ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done
```

### Example 3: Field Separator

**Before (bash):**
```bash
#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
```

**After (POSIX sh):**
```sh
#!/bin/sh
set -eu
IFS='
	'
```

### Example 4: Pattern Matching

**Before (bash):**
```bash
#!/bin/bash
if [[ "$filename" == *.txt ]]; then
    echo "Text file"
fi
```

**After (POSIX sh):**
```sh
#!/bin/sh
case "$filename" in
    *.txt) echo "Text file" ;;
esac
```

### Example 5: String Contains

**Before (bash):**
```bash
#!/bin/bash
if [[ "$string" == *"substring"* ]]; then
    echo "Found"
fi
```

**After (POSIX sh):**
```sh
#!/bin/sh
case "$string" in
    *"substring"*) echo "Found" ;;
esac
```

### Example 6: Secure Password Input

**Before (bash):**
```bash
#!/bin/bash
read -s -p "Password: " password
echo ""
```

**After (POSIX sh):**
```sh
#!/bin/sh
printf "Password: "
stty -echo
read password
stty echo
printf "\n"
```

### Example 7: For Loop with Sequence

**Before (bash):**
```bash
#!/bin/bash
for i in {1..10}; do
    echo "Number: $i"
done
```

**After (POSIX sh):**
```sh
#!/bin/sh
i=1
while [ $i -le 10 ]; do
    echo "Number: $i"
    i=$((i + 1))
done
```

### Example 8: String Substitution

**Before (bash):**
```bash
#!/bin/bash
filename="test.txt.backup"
echo "${filename//.txt/}"
```

**After (POSIX sh):**
```sh
#!/bin/sh
filename="test.txt.backup"
echo "$filename" | sed 's/\.txt//'
```

## Migration Checklist

When converting bash scripts to POSIX sh:

- [ ] Change shebang from `#!/bin/bash` to `#!/bin/sh`
- [ ] Change `set -euo pipefail` to `set -eu`
- [ ] Replace `IFS=$'\n\t'` with literal newline/tab
- [ ] Replace `[[ ... ]]` with `[ ... ]`
- [ ] Replace `echo -e` with `printf`
- [ ] Replace bash arrays with alternative approaches
- [ ] Replace `${var//old/new}` with sed
- [ ] Replace `${var:n:m}` with cut/awk
- [ ] Replace `read -s` with stty -echo/echo
- [ ] Replace `read -p` with printf + read
- [ ] Replace `source` with `.` (dot command)
- [ ] Replace `{1..10}` ranges with while loops
- [ ] Test on Alpine Linux (ash/busybox)
- [ ] Verify with shellcheck --shell=sh

## References

- POSIX Shell specification: https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html
- Dash (Debian Almquist Shell): https://git.kernel.org/pub/scm/utils/dash/dash.git
- BusyBox sh: https://busybox.net/
- Rich's sh tricks: https://www.etalabs.net/sh_tricks.html
- Shellcheck POSIX mode: https://github.com/koalaman/shellcheck
- Alpine Linux shell: https://wiki.alpinelinux.org/wiki/Alpine_Linux:FAQ
