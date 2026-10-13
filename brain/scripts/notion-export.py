#!/usr/bin/env python3
"""Export a Notion page to Markdown via the REST API (no MCP, no context cost).

Usage:
    notion-export.py PAGE_ID OUT.md [--title "Override title"]

Token: read from ~/.claude/mcpServers.json -> mcpServers.notion.env.NOTION_TOKEN,
or the NOTION_TOKEN environment variable.
Child pages are listed as links, not inlined; export them separately.
"""
import datetime as dt
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

API = "https://api.notion.com/v1"
VERSION = "2022-06-28"
SLEEP = 0.34  # stay under 3 req/s


def token() -> str:
    t = os.environ.get("NOTION_TOKEN")
    if t:
        return t
    cfg = json.loads((Path.home() / ".claude" / "mcpServers.json").read_text())

    def find(o):
        if isinstance(o, dict):
            if "NOTION_TOKEN" in o:
                return o["NOTION_TOKEN"]
            for v in o.values():
                r = find(v)
                if r:
                    return r
        elif isinstance(o, list):
            for v in o:
                r = find(v)
                if r:
                    return r
        return None

    t = find(cfg)
    if not t:
        raise SystemExit("NOTION_TOKEN not found in ~/.claude/mcpServers.json or env")
    return t


def get(path: str, params: dict | None = None) -> dict:
    url = API + path
    if params:
        url += "?" + "&".join(f"{k}={v}" for k, v in params.items())
    req = urllib.request.Request(url, headers={
        "Authorization": f"Bearer {token()}",
        "Notion-Version": VERSION,
    })
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                time.sleep(SLEEP)
                return json.load(r)
        except urllib.error.HTTPError as e:
            if e.code == 429:
                time.sleep(float(e.headers.get("Retry-After", "2")))
                continue
            body = e.read().decode("utf-8", "replace")
            raise SystemExit(f"HTTP {e.code} on {path}: {body[:300]}")
    raise SystemExit(f"gave up on {path}")


def rich(rts: list) -> str:
    out = []
    for r in rts:
        t = r.get("plain_text", "")
        a = r.get("annotations", {})
        if a.get("code"):
            t = f"`{t}`"
        if a.get("bold"):
            t = f"**{t}**"
        if a.get("italic"):
            t = f"*{t}*"
        if a.get("strikethrough"):
            t = f"~~{t}~~"
        href = r.get("href")
        if href and r.get("type") == "text":
            t = f"[{t}]({href})"
        out.append(t)
    return "".join(out)


def children(block_id: str) -> list:
    blocks, cursor = [], None
    while True:
        params = {"page_size": 100}
        if cursor:
            params["start_cursor"] = cursor
        res = get(f"/blocks/{block_id}/children", params)
        blocks.extend(res.get("results", []))
        if not res.get("has_more"):
            return blocks
        cursor = res["next_cursor"]


def render(blocks: list, depth: int = 0, counter: list | None = None) -> list[str]:
    lines: list[str] = []
    pad = "  " * depth
    n = 0
    for b in blocks:
        t = b["type"]
        d = b.get(t, {})
        text = rich(d.get("rich_text", [])) if isinstance(d, dict) else ""
        kids = children(b["id"]) if b.get("has_children") else []

        if t == "paragraph":
            lines += [pad + text if text else "", ""]
        elif t in ("heading_1", "heading_2", "heading_3"):
            lines += [pad + "#" * int(t[-1]) + " " + text, ""]
        elif t == "bulleted_list_item":
            lines.append(pad + "- " + text)
        elif t == "numbered_list_item":
            n += 1
            lines.append(pad + f"{n}. " + text)
        elif t == "to_do":
            box = "[x]" if d.get("checked") else "[ ]"
            lines.append(pad + f"- {box} " + text)
        elif t == "toggle":
            lines.append(pad + "- ▸ " + text)
        elif t == "quote":
            lines += [pad + "> " + text, ""]
        elif t == "callout":
            icon = (d.get("icon") or {}).get("emoji", "")
            lines += [pad + f"> {icon} " + text, ""]
        elif t == "divider":
            lines += [pad + "---", ""]
        elif t == "code":
            lang = d.get("language", "")
            lines += [pad + f"```{lang}", text, pad + "```", ""]
        elif t == "table":
            rows = kids
            kids = []
            for i, row in enumerate(rows):
                cells = [rich(c) for c in row.get("table_row", {}).get("cells", [])]
                lines.append(pad + "| " + " | ".join(cells) + " |")
                if i == 0:
                    lines.append(pad + "|" + "---|" * len(cells))
            lines.append("")
        elif t == "child_page":
            lines += [pad + f"📄 Sub-page: **{d.get('title','')}** (Notion id `{b['id'].replace('-','')}`, exported separately)", ""]
        elif t == "child_database":
            lines += [pad + f"🗄 Database: {d.get('title','')}", ""]
        elif t in ("image", "file", "video", "pdf", "bookmark", "embed", "link_preview"):
            src = d.get("external", {}).get("url") or d.get("file", {}).get("url") or d.get("url", "")
            cap = rich(d.get("caption", []))
            lines += [pad + f"[{t}: {cap or src[:80]}]", ""]
        elif t in ("column_list", "column", "synced_block"):
            pass  # just recurse
        elif t == "table_of_contents":
            pass
        else:
            lines += [pad + f"[unsupported block: {t}]", ""]

        if kids:
            lines += render(kids, depth + 1 if t in ("bulleted_list_item", "numbered_list_item", "to_do", "toggle") else depth)
            if t in ("bulleted_list_item", "numbered_list_item", "to_do", "toggle"):
                pass
    return lines


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print(__doc__)
        return 2
    page_id, out = argv[1], Path(argv[2])
    override = argv[4] if len(argv) > 4 and argv[3] == "--title" else None
    page = get(f"/pages/{page_id}")
    title = override or "".join(
        t["plain_text"] for p in page["properties"].values() if p["type"] == "title" for t in p["title"]
    )
    url = page.get("url", "")
    edited = page.get("last_edited_time", "")
    body = "\n".join(render(children(page_id)))
    # collapse runs of blank lines
    while "\n\n\n" in body:
        body = body.replace("\n\n\n", "\n\n")
    front = (
        f"# {title}\n\n"
        f"*Source: Notion, {url}  \n"
        f"Notion last edited: {edited[:10]}  \n"
        f"Exported: {dt.date.today().isoformat()} via notion-export.py*\n\n---\n\n"
    )
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(front + body.strip() + "\n", encoding="utf-8")
    print(f"{out.name}: {len(front) + len(body):,} chars, title={title!r}, edited={edited[:10]}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
