#!/usr/bin/env python3
"""
Remove the leading '# Heading' from markdown files that have a `title:`
frontmatter — Cayman renders page.title as <h1>, so the markdown H1 is duplicated.

Safe behavior:
  - Only touches files with YAML frontmatter containing `title:`.
  - Removes ONLY the first H1 after the frontmatter (and any blank line after it).
  - Skips files where the first non-frontmatter heading is NOT an H1.
  - Skips files where there's no frontmatter title.

Run:
  python3 scripts/remove-duplicate-h1.py
  python3 scripts/remove-duplicate-h1.py --dry-run   # preview without writing
"""
import sys, re
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent
DRY_RUN = '--dry-run' in sys.argv

# Collect all .md files outside _site, .git, node_modules, templates
md_files = []
for p in BASE.rglob('*.md'):
    s = str(p.relative_to(BASE))
    if any(part in s for part in ['_site/', '.git/', 'node_modules/']):
        continue
    md_files.append(p)

FRONT_PAT = re.compile(r'^(---\s*\n.*?\n---\s*\n)', re.DOTALL)
H1_PAT    = re.compile(r'^# [^\n]+\n+', re.MULTILINE)

changed = 0
skipped_no_fm = 0
skipped_no_title = 0
skipped_no_h1 = 0

for f in sorted(md_files):
    text = f.read_text()
    m = FRONT_PAT.match(text)
    if not m:
        skipped_no_fm += 1
        continue
    fm = m.group(1)
    if 'title:' not in fm:
        skipped_no_title += 1
        continue

    body = text[m.end():]
    # Remove leading blank lines from body for analysis
    body_stripped = body.lstrip('\n')
    if not body_stripped.startswith('# '):
        skipped_no_h1 += 1
        continue

    # Find the first H1 line + any blank line after it
    new_body = re.sub(r'^# [^\n]+\n+', '', body_stripped, count=1)

    new_text = fm + '\n' + new_body
    if new_text == text:
        continue

    rel = f.relative_to(BASE)
    if DRY_RUN:
        old_h1 = body_stripped.split('\n', 1)[0]
        print(f'  WOULD-REMOVE  {rel}: {old_h1!r}')
    else:
        f.write_text(new_text)
        print(f'  REMOVED       {rel}')
    changed += 1

print()
print(f'Files changed:        {changed}')
print(f'Skipped (no frontmatter):    {skipped_no_fm}')
print(f'Skipped (no title in FM):    {skipped_no_title}')
print(f'Skipped (no H1 after FM):    {skipped_no_h1}')
print(f'Total scanned:        {len(md_files)}')
if DRY_RUN:
    print('\n(dry run — no files written. Rerun without --dry-run to apply.)')
