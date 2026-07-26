# 4-brain

A Claude Code skill that routes work to **Codex**, **Gemini**, and **Grok** when a task fits their distinct strengths better than Claude alone. Claude stays the driver: it assigns lenses, adjudicates every finding, runs the proof, and does the fixing.

It exists to kill one specific failure mode: **Claude reviewing Claude's own work.** Same architecture, same blind spots.

## Why four

These lenses were measured on a single ~6,400-line review. Each model surfaced a defect class the others entirely missed:

| Brain | Catches |
|---|---|
| **Codex** | Code-path correctness, concurrency, races, migration-vs-real-data hazards |
| **Gemini** | Breadth across many files at once; long context; video/audio/image/PDF |
| **Grok** | Product/ops/regulatory reality — does it work end-to-end, what breaks on deploy, copy that lies |
| **Claude** | Adjudication, verification against source, the actual proof run, the fix |

The corollary: **give each brain a different lens.** Ask four models the same generic question and you pay four times for one answer.

## Install

Requires [Claude Code](https://claude.com/claude-code), plus whichever brains you want available on `PATH`:
[`codex`](https://github.com/openai/codex) · [`gemini`](https://github.com/google-gemini/gemini-cli) · [`grok`](https://x.ai)

Missing CLIs degrade gracefully — the skill announces it once and drops that route.

```bash
git clone <this-repo> 4-brain
cd 4-brain

# macOS / Linux
./install.sh

# Windows (PowerShell)
./install.ps1
```

Both installers link `skill/` into `~/.claude/skills/4-brain` so the repo stays the source of truth — `git pull` updates the skill everywhere. Pass `--copy` if you'd rather have an independent copy.

Verify:
```
/4-brain
```

## Usage

It mostly fires on its own. Explicitly:

```
/4-brain review the changes on this branch
/4-brain ask all four whether this schema migration is safe
```

It **must** fire whenever you ask Claude to check, review, audit, verify, or sanity-check its own work.

## Model currency

The skill never pins model versions and never passes `-m`. Each CLI's configured default wins, so the stack picks up new models the day the vendor ships them. At session start it echoes the resolved CLI versions so drift is visible instead of silent.

To change which model a brain uses, change that CLI's own config (e.g. `~/.codex/config.toml`) — not this skill.

## Output

Runs file to `./.4-brain-out/<date>-<slug>/` in the current project, plus a one-line entry in `.4-brain-out/log.md`. That ledger accumulates evidence of which brain earns its keep on which kind of work.

Add `.4-brain-out/` to your project's `.gitignore` unless you want reviews committed.

## The one rule that matters most

**Verify every finding before acting on it.** Confident, well-argued, and wrong is the normal failure mode of every model here — including the ones you're paying for a second opinion. Reject bad findings with a logged reason; caving to everything defeats the cross-check as surely as ignoring it.

## Lineage

Successor to an earlier three-brain skill (Claude + Codex + Gemini). The routing/announcement structure was influenced by Matt Pocock's `grill-me` (MIT).

## License

MIT — see [LICENSE](LICENSE).
