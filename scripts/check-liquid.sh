#!/usr/bin/env bash
# Detect Liquid-conflicting syntax in markdown files BEFORE pushing.
# Liquid sees {{...}} as variable interpolation; n8n/Make use the same syntax
# in code examples, which can crash Jekyll's build on GitHub Pages.
#
# This script does NOT need Ruby / Bundler / Docker — pure grep.
# Run before every push: ./scripts/check-liquid.sh
#
# Exit codes:
#   0 — no issues found
#   1 — issues found (review and wrap with {% raw %} ... {% endraw %})

set -euo pipefail

cd "$(dirname "$0")/.."

echo "Checking for Liquid-conflicting patterns in *.md files..."

declare -i issues=0

# Pattern 1: {{ $var }} or {{$var}} — n8n/Make expression syntax
# Liquid sees the $ as invalid character.
echo
echo "=== Pattern 1: {{ \$var }} or {{\$var}} (n8n/Make expressions) ==="
if grep -rn --include='*.md' -E '\{\{[^}]*\$' . | grep -v '^[^:]*:.*\{%[[:space:]]*raw[[:space:]]*%\}'; then
    issues=$((issues + 1))
fi

# Pattern 2: {{ name (...) }} with an opening brace { inside — fatal
# Like {{ $now.minus({hours: 24}).toISO() }}
echo
echo "=== Pattern 2: {{ ... { ... }} — opening brace inside Liquid block (FATAL) ==="
if grep -rn --include='*.md' -E '\{\{[^}]*\{[^}]*\}\}' . | grep -v '^[^:]*:.*\{%[[:space:]]*raw[[:space:]]*%\}'; then
    issues=$((issues + 1))
fi

# Pattern 3: Unmatched {{ — would cause runaway Liquid parse
echo
echo "=== Pattern 3: Lines with {{ but no closing }} ==="
# Find lines with `{{` not followed by matching `}}` on the same line.
# Excludes lines in {% raw %} blocks (basic heuristic — does not handle multi-line raw blocks).
awk '
    /\{% *raw *%\}/ {in_raw=1}
    /\{% *endraw *%\}/ {in_raw=0; next}
    in_raw {next}
    /\{\{/ {
        line = $0
        # Count {{ and }} occurrences
        gsub(/[^{]/, "", line); opens = length(line) / 2
        line = $0
        gsub(/[^}]/, "", line); closes = length(line) / 2
        if (opens > closes) print FILENAME ":" FNR ": " $0
    }
' $(find . -name '*.md' -not -path './_site/*' -not -path './node_modules/*') && true

# Pattern 4: Files containing {{ but missing render_with_liquid: false in frontmatter
# (Optional informational check — render_with_liquid is Jekyll 4+ only, ignored on GH Pages 3.x)
# Not a hard fail — just a note.
echo
echo "=== Files with {{ that lack {% raw %} wrappers ==="
for f in $(grep -rl --include='*.md' '{{' . 2>/dev/null | grep -v _site); do
    if ! grep -q 'raw %}' "$f"; then
        # Check if it has Liquid-conflicting syntax
        if grep -qE '\{\{[^}]*(\$|\{)' "$f"; then
            echo "  $f — has {{...}} with \$ or { but no {% raw %} wrapper"
        fi
    fi
done

echo
if [[ $issues -eq 0 ]]; then
    echo "✓ No Liquid-conflicting patterns detected. Safe to push."
    exit 0
else
    echo "✗ $issues type(s) of Liquid issue found above. Wrap problematic code blocks with:"
    echo
    echo "    {% raw %}"
    echo "    ```your-code-here"
    echo "    ```"
    echo "    {% endraw %}"
    echo
    echo "Or add 'render_with_liquid: false' to frontmatter (but this is Jekyll 4+ only;"
    echo "GitHub Pages still runs Jekyll 3.10, so {% raw %} is the safer fix today)."
    exit 1
fi
