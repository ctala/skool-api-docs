#!/usr/bin/env python3
"""
indexnow-ping.py — notify Bing/Yandex/Naver/Seznam of new/updated doc-site URLs.

IndexNow is for non-Google engines (Google uses GSC + sitemap, not IndexNow).
The key is public (lives in a public .txt at the site root), so it's fine in-repo.

Usage:
  python3 scripts/indexnow-ping.py                      # ping ALL integrations + recipes pages
  python3 scripts/indexnow-ping.py <url> [<url> ...]    # ping specific URLs
  python3 scripts/indexnow-ping.py --dry-run            # show the payload without sending

Run from the repo root (it reads slugs from integrations/*.md and recipes/*.md).
"""
import glob, re, sys, json, urllib.request, urllib.error

HOST = "ctala.github.io"
BASE = "https://ctala.github.io/skool-api-docs"
KEY = "b450a501c39946cea17cee111bcf08f5"  # public key — file lives at {BASE}/{KEY}.txt
KEY_LOCATION = f"{BASE}/{KEY}.txt"


def urls_from_slugs():
    urls = []
    for p in sorted(glob.glob("integrations/*.md") + glob.glob("recipes/*.md")):
        t = open(p).read()
        m = re.search(r"^slug:\s*(\S+)", t, re.M)
        if not m:
            continue
        urls.append(f"{BASE}{m.group(1).strip()}/")
    return sorted(set(urls))


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    urls = args if args else urls_from_slugs()
    if not urls:
        sys.exit("No URLs to ping (run from repo root, or pass URLs as args).")

    payload = {"host": HOST, "key": KEY, "keyLocation": KEY_LOCATION, "urlList": urls}

    if "--dry-run" in sys.argv:
        print(json.dumps(payload, indent=2))
        return

    req = urllib.request.Request(
        "https://api.indexnow.org/indexnow",
        data=json.dumps(payload).encode(),
        method="POST",
        headers={"Content-Type": "application/json; charset=utf-8"},
    )
    try:
        r = urllib.request.urlopen(req, timeout=30)
        print(f"IndexNow → HTTP {r.status} (200/202 = accepted) · {len(urls)} URLs")
    except urllib.error.HTTPError as e:
        # 403 SiteVerificationNotCompleted = key file just uploaded, wait 2-5 min
        print(f"IndexNow → HTTP {e.code}: {e.read().decode()[:200]}")
        sys.exit(1)
    for u in urls:
        print(" ", u)


if __name__ == "__main__":
    main()
