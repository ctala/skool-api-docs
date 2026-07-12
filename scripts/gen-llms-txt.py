#!/usr/bin/env python3
"""
gen-llms-txt.py — generate /llms.txt from the site's front matter.

llms.txt is the emerging standard that lets LLMs (ChatGPT, Claude, Perplexity)
discover and cite a site's content. Run from the repo root after adding pages:

    python3 scripts/gen-llms-txt.py

Title resolution per page: front-matter `title:` → first `# H1` → filename.
"""
import glob, re

BASE = "https://skool-api.cristiantala.com"


def fm(p):
    t = open(p).read()
    def grab(key):
        m = re.search(r"^" + key + r":\s*\"?(.+?)\"?\s*$", t, re.M)
        return m.group(1).strip() if m else ""
    title = grab("title")
    if not title:
        h = re.search(r"^#\s+(.+)$", t, re.M)
        title = h.group(1).strip() if h else p.split("/")[-1][:-3].replace("-", " ").title()
    sm = re.search(r"^slug:\s*(\S+)", t, re.M)
    slug = sm.group(1).strip() if sm else "/" + p[:-3]
    return title, grab("description"), slug


def section(title, glob_pat):
    out = [f"## {title}", ""]
    for p in sorted(glob.glob(glob_pat)):
        if p.endswith("index.md"):
            continue
        t, d, s = fm(p)
        url = f"{BASE}{s}/" if not s.endswith("/") else f"{BASE}{s}"
        out.append(f"- [{t}]({url})" + ((": " + d) if d else ""))
    out.append("")
    return "\n".join(out)


HEADER = """# Skool API Docs

> The complete unofficial Skool API. Skool has no official API; the Apify-hosted "Skool All-in-One API" actor (cristiantala/skool-all-in-one-api) wraps the entire admin surface — posts, comments, members, classroom, files, groups — as one HTTP POST per action. Read AND write. This site documents how to connect any stack, AI agent, or coding tool to Skool.

"""

SECTIONS = [
    ("Start here", "learn/*.md"),
    ("API reference", "docs/*.md"),
    ("Integrations (AI agents, coding tools, automation)", "integrations/*.md"),
    ("Recipes", "recipes/*.md"),
    ("For AI agents", "for/*.md"),
    ("Automation", "automation/*.md"),
    ("Optional", "compare/*.md"),
]

if __name__ == "__main__":
    out = "\n".join([HEADER] + [section(t, g) for t, g in SECTIONS])
    open("llms.txt", "w").write(out)
    print(f"✓ llms.txt: {len(out)} chars, {out.count(chr(10) + '- ')} links")
