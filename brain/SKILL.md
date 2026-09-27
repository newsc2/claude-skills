---
name: brain
description: Use when Tony asks what he has been thinking, feeling, or writing about (recently or historically) in his journal, diaries, notes, or email — his "digital brain" — or asks for a reflection on a person, decision, or pattern in his life, or asks to save such a reflection to the AI folder in his Apple Notes.
---

# Brain

Tony's personal-reflection project: read his own records in full, talk to him like a friend who knows the record, save the result as a dated note only when he asks.

## Sources — sweep every one that could hold the answer

Answering from a single source is the failure mode. Check all of these:

| Source | Where | How |
|---|---|---|
| Apple Notes journal (Apr 2026→; monthly "May 2026", "Sept 2026"…) and 2010–2016 phone notes | iCloud `Notes` folder; Google `Notes` folder | `~/.claude/skills/brain/scripts/export-notes.sh OUT.txt` then grep the dump |
| Evernote archive 2012–2026 (1,939 notes) | `~/Projects/evernote-migration/data/markdown/YYYY/*.md`, `data/inventory.csv` | grep -ril, read matches in full |
| Email and Gchat logs (2011→) | Gmail MCP `search_threads` / `get_thread` (PLAIN_TEXT) | Results >25K chars land in a file: `jq` it. Gchat logs are threads labeled `CHAT` |
| Prior reflections | Apple Notes `AI` folder | Read any existing note on the topic before writing a new one |
| Standing facts, corrections, voice | memory: `notes-ai-folder.md`, `feedback_plain_voice_personal_talks.md`, `evernote-migration.md` | Read before answering |
| Secondary | Notion monthly to-do; The Studio (`~/Documents/Amazon Docs/studio`) | Only when the question points there |

## Procedure

1. Read memory corrections and any prior AI-folder note on the topic.
2. Sweep sources. Read matching material in full, with dates; "recently" means the last few months of the journal plus anything older that bears on it.
3. Separate what he wrote from what he pasted. Things he typed while listening (therapy notes, 1:1s, "Chat:" sections) are his; verbatim pastes of AI output, forwards, and other people's messages are not his self-assessment. In Gmail, weight sent mail (what he told others); inbound is context.
4. Answer in chat.
5. If he asks to save or draft a note, the note is the full write-up, not the chat paragraph: write HTML to the scratchpad with `<h1>YYYY-MM-DD — Title</h1>` (today's date), then `~/.claude/skills/brain/scripts/save-note.sh FILE.html`. Use `--replace "exact title"` to update an existing note instead of creating one.

## What the answer is

Flowing conversational paragraphs addressed to him. His own words quoted with dates, then interpretation, labeled as interpretation. Plain pushback where his record contradicts what he's saying now. Concrete over aphoristic; every claim traceable to something he wrote. Bullets only when he asks for bullets. Notes skew toward problems; he has said most of his life happens outside them, so read through the anxieties rather than treating them as the person.

## Common mistakes

- Answering from Apple Notes alone. Gmail holds the 2011–2014 record; Evernote holds 2012–2026.
- `body of note` returns empty over AppleScript; use `plaintext of note`. Length coercions inside the same script error out; verify in a second call.
- Reintroducing a reading Tony has retracted (listed in `notes-ai-folder.md`).
- Modeling him instead of quoting him.
