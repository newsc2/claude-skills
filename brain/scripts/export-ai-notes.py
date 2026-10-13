#!/usr/bin/env python3
"""Export Claude-written notes from the Apple Notes `AI` folder to HTML + Markdown.

Usage:
    export-ai-notes.py OUT_DIR                # every note whose title starts YYYY-MM
    export-ai-notes.py OUT_DIR "exact title"  # just the named note(s)

Writes OUT_DIR/<slug>.html (Notes' own HTML body, lossless) and OUT_DIR/<slug>.md.
Slug = title lowercased, non-alphanumerics collapsed to '-'.
If `body` comes back empty (iCloud has not pulled the note down yet) the script
asks Notes to `show` the note, waits, retries, and finally falls back to plaintext.
"""
import re
import subprocess
import sys
import time
from html.parser import HTMLParser
from pathlib import Path

DATED = re.compile(r"^\d{4}-\d{2}")

LIST_TITLES = '''
tell application "Notes" to tell account "iCloud"
  set out to ""
  repeat with n in notes of folder "AI"
    set out to out & (name of n) & linefeed
  end repeat
  return out
end tell
'''

GET = '''
on run argv
  set theTitle to item 1 of argv
  set theProp to item 2 of argv
  tell application "Notes" to tell account "iCloud"
    set n to first note of folder "AI" whose name is theTitle
    if theProp is "body" then
      return body of n
    else if theProp is "plaintext" then
      return plaintext of n
    else if theProp is "show" then
      show n
      return "shown"
    end if
  end tell
end run
'''


def osa(script: str, *args: str) -> str:
    out = subprocess.run(["osascript", "-", *args], input=script, capture_output=True, text=True, check=True)
    return out.stdout


def slugify(title: str) -> str:
    s = title.lower().replace("—", "-").replace("–", "-")
    s = re.sub(r"[^a-z0-9]+", "-", s)
    return s.strip("-")


class NotesToMarkdown(HTMLParser):
    """Apple Notes emits flat <div> lines; headings are <b><span style="font-size:NNpx">.

    24px -> '# ', 18px -> '## '; inline <b>/<i> -> **/*; <ul>/<ol>/<li> -> lists; <a> -> [text](href).
    """

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.lines: list[str] = []
        self.cur: list[str] = []
        self.list_stack: list[str] = []
        self.ol_counts: list[int] = []
        self.pending_heading: str | None = None
        self.in_li = False
        self.href: str | None = None

    def flush(self):
        text = "".join(self.cur).strip()
        if self.pending_heading and text:
            text = self.pending_heading + text.strip("*")
        if self.in_li and text:
            if self.list_stack and self.list_stack[-1] == "ol":
                self.ol_counts[-1] += 1
                text = f"{self.ol_counts[-1]}. {text}"
            else:
                text = f"- {text}"
            text = "  " * (len(self.list_stack) - 1) + text
        self.lines.append(text)
        self.cur = []
        self.pending_heading = None

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag in ("div", "br"):
            self.flush()
        elif tag == "span":
            m = re.search(r"font-size:\s*(\d+)px", a.get("style", ""))
            if m:
                px = int(m.group(1))
                if px >= 22:
                    self.pending_heading = "# "
                elif px >= 16:
                    self.pending_heading = "## "
        elif tag == "b":
            if self.pending_heading is None:
                self.cur.append("**")
        elif tag == "i":
            self.cur.append("*")
        elif tag in ("ul", "ol"):
            self.flush()
            self.list_stack.append(tag)
            self.ol_counts.append(0)
        elif tag == "li":
            self.flush()
            self.in_li = True
        elif tag == "a":
            self.href = a.get("href")
            self.cur.append("[")

    def handle_endtag(self, tag):
        if tag == "div":
            self.flush()
        elif tag == "b":
            if self.pending_heading is None:
                self.cur.append("**")
        elif tag == "i":
            self.cur.append("*")
        elif tag in ("ul", "ol"):
            self.flush()
            if self.list_stack:
                self.list_stack.pop()
                self.ol_counts.pop()
            self.lines.append("")
        elif tag == "li":
            self.flush()
            self.in_li = False
        elif tag == "a":
            self.cur.append(f"]({self.href})" if self.href else "]")
            self.href = None

    def handle_data(self, data):
        self.cur.append(data.replace("\xa0", " "))

    def result(self) -> str:
        self.flush()
        out: list[str] = []
        blank = 0
        for ln in self.lines:
            if ln == "":
                blank += 1
                if blank > 1:
                    continue
            else:
                blank = 0
            out.append(ln)
        md = "\n".join(out).strip() + "\n"
        return re.sub(r"\*\*\s*\*\*", "", md)


def fetch(title: str) -> tuple[str, str]:
    """Return (html, markdown). Falls back to plaintext if the body never syncs."""
    body = osa(GET, title, "body").strip()
    if not body:
        osa(GET, title, "show")
        for _ in range(6):
            time.sleep(5)
            body = osa(GET, title, "body").strip()
            if body:
                break
    if body:
        p = NotesToMarkdown()
        p.feed(body)
        return body, p.result()
    text = osa(GET, title, "plaintext").strip()
    if not text:
        raise RuntimeError(f"{title!r}: body and plaintext both empty (not synced yet?)")
    return "", f"# {title}\n\n" + text + "\n"


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 2
    out_dir = Path(argv[1])
    out_dir.mkdir(parents=True, exist_ok=True)
    titles = argv[2:] or [t for t in osa(LIST_TITLES).splitlines() if DATED.match(t)]
    failed = 0
    for title in sorted(titles):
        slug = slugify(title)
        try:
            html, md = fetch(title)
        except RuntimeError as e:
            print(f"SKIP {e}")
            failed += 1
            continue
        if html:
            (out_dir / f"{slug}.html").write_text(html, encoding="utf-8")
        (out_dir / f"{slug}.md").write_text(md, encoding="utf-8")
        print(f"{slug}: html {len(html):>6}, md {len(md):>6} chars{'' if html else '  (plaintext fallback)'}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
