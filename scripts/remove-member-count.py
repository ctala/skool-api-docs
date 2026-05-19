#!/usr/bin/env python3
"""
Remove specific member-count references ("484 members", "484-member", etc.)
that go stale fast.

Safe: ONLY matches phrases that contain "484", no whitespace collapsing,
no generic catch-all that would touch unrelated content.
"""
import re, sys
from pathlib import Path

DRY_RUN = '--dry-run' in sys.argv

# Each pattern: (regex, replacement). Order matters — longer/more-specific first.
REPLACEMENTS = [
    # ------- title / heading variants -------
    (r'Honest Take After Running a 484-Member Community',  'Honest Take After Running a Paid Community'),
    (r'Running a 484-Member Community',                    'Running a Paid Community'),

    # ------- "Battle-tested ... on a 484-member ..." in CTAs -------
    (r'Built and battle-tested on a 484-member production Skool community',  'Built and battle-tested in production'),
    (r'Built and battle-tested on a 484-member production community',        'Built and battle-tested in production'),
    (r'Built and battle-tested on a 484-member Skool community',             'Built and battle-tested in production'),

    (r'Battle-tested in production on a 484-member production Skool community', 'Battle-tested in production'),
    (r'Battle-tested in production on a 484-member production community',       'Battle-tested in production'),
    (r'Battle-tested in production on a 484-member Skool community',            'Battle-tested in production'),
    (r'Battle-tested on a 484-member production Skool community',               'Battle-tested in production'),
    (r'Battle-tested on a 484-member production community',                     'Battle-tested in production'),
    (r'Battle-tested on a 484-member Skool community',                          'Battle-tested in production'),
    (r'Battle-tested on a 484-member community',                                'Battle-tested in production'),

    # production-tested
    (r'production-tested on a 484-member production Skool community',  'production-tested in a real Skool community'),
    (r'production-tested on a 484-member production community',        'production-tested in a real Skool community'),
    (r'production-tested on a 484-member Skool community',             'production-tested in a real Skool community'),
    (r'production-tested on a 484-member community',                   'production-tested in a real Skool community'),

    # "powers a real production community (...— 484 founders, ..."
    (r' — 484 founders,',           ' —'),
    (r' — 484 members,',            ' —'),

    # Parentheticals
    (r' \(484 members\)',           ''),
    (r' \(484 founders\)',          ''),
    (r' \(484\+ members\)',         ''),
    (r' \(484\+ founders\)',        ''),

    # "community of 484 founders" / "community of 484 members"
    (r'community of 484 founders',  'community of founders'),
    (r'community of 484 members',   'real community'),
    (r'a community of 484 ',        'a community of '),

    # "484-member production Skool community" (standalone, in narrative)
    (r'484-member production Skool community',  'production Skool community'),
    (r'484-member production community',        'production Skool community'),
    (r'484-member Skool community',             'production Skool community'),
    (r'484-member community',                   'production Skool community'),

    # "grow a community to 484 members" → drop the target
    (r'grow a community to 484 members',  'grow your community'),

    # "Battle-tested in production on a 484-member ..." (most-specific first)
    (r'Battle-tested in production on a 484-member production Skool community',  'Battle-tested in production'),
    (r'Battle-tested in production on a 484-member Skool community',             'Battle-tested in production'),
    (r'Battle-tested in production on a 484-member community',                   'Battle-tested in production'),

    # "ranked by impact on engagement and time saved on a 484-member community"
    (r'on a 484-member community',  'in a real Skool community'),

    # description tags with "from 484-member community"
    (r'Real production patterns from a 484-member community',  'Real production patterns from a working paid community'),
    (r'Real production patterns from 484-member community',    'Real production patterns from a working paid community'),
    (r'Production recipe from a 484-member community',         'Production recipe from a working paid community'),

    # Standalone "484 members" / "484 founders" as nouns
    (r'\b484 members\b',            'real members'),
    (r'\b484 founders\b',           'real founders'),
    (r'\b484 paid members\b',       'a real paid membership base'),
]

BASE = Path(__file__).resolve().parent.parent

files = []
for ext in ('*.md', '*.html'):
    for p in BASE.rglob(ext):
        s = str(p.relative_to(BASE))
        if any(part in s for part in ['_site/', '.git/', 'node_modules/']):
            continue
        files.append(p)

total_changes = 0
total_files = 0
preview_lines = []

for f in sorted(files):
    text = f.read_text()
    new_text = text
    file_changes = 0
    for pat, repl in REPLACEMENTS:
        new_text, n = re.subn(pat, repl, new_text)
        file_changes += n

    if file_changes == 0:
        continue

    rel = f.relative_to(BASE)
    if DRY_RUN:
        # Show all changed lines
        old_lines = text.splitlines()
        new_lines = new_text.splitlines()
        for i, (o, n) in enumerate(zip(old_lines, new_lines)):
            if o != n:
                preview_lines.append((str(rel), i + 1, o, n))
    else:
        f.write_text(new_text)
        print(f'  {rel}: {file_changes} replacements')

    total_changes += file_changes
    total_files += 1

if DRY_RUN:
    for rel, line, old, new in preview_lines:
        print(f'{rel}:{line}')
        print(f'  - {old}')
        print(f'  + {new}')
        print()

print(f'Files changed:    {total_files}')
print(f'Total replacements: {total_changes}')
if DRY_RUN:
    print('\n(dry run — rerun without --dry-run to apply)')

# Final check: lines still mentioning 484
print()
print('Remaining "484" references in repo (manual review):')
import subprocess
out = subprocess.run(['grep', '-rn', '484', '--include=*.md', '--include=*.html', '.'],
                     capture_output=True, text=True, cwd=BASE)
remaining = [l for l in out.stdout.splitlines() if '_site/' not in l and '.git/' not in l]
for line in remaining:
    print('  ' + line)
