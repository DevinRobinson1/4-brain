---
name: 4-brain
description: |
  Routes work to Codex, Gemini, or Grok when a task fits their distinct strengths better than Claude alone. Claude stays the driver — the others are tools it calls, and Claude adjudicates every finding.

  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  HARD RULE — THE NO-SELF-REVIEW LAW (READ THIS FIRST)
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  When the user asks Claude to "check / review / look over / proof / verify / audit / sanity-check / second-opinion" ANY work Claude just produced — code, writing, plan, design, anything — this is a MUST-FIRE situation. Route to at least one external brain.

  Claude reviewing Claude's own output is the exact failure mode this skill exists to prevent. Same architecture, same blind spots. A self-review catches nothing meaningful.

  Phrases that MUST trigger an external review (not exhaustive):
  "check over your work" / "review what you just did" / "look over this" / "is this right?" /
  "second opinion" / "sanity check" / "double-check" / "proof this" / "audit this" / "make sure this works"

  Do NOT silently self-review. Do NOT say "I'll review it inline."

  Also fires on: "ask all four", "cross-model check", "grill this", "what would X say",
  and any task needing eyes/ears Claude lacks (video, audio, images, very long documents).
---

# 4-Brain — One Driver, Four Perspectives

Four models, one terminal. Claude drives and stays in front of the user; the others are called as tools.

| Brain | CLI | Proven lens — what it catches that others miss |
|---|---|---|
| **Claude** (Opus 5.5) | (you) | Driver. Adjudicates findings, verifies claims against source, runs the actual proof, does the fixing. |
| **Codex** (GPT-6.1 Sol `gpt-6.1-sol` at medium effort, for review and for builds via `/codex-build`) | `codex` | Code-path correctness, concurrency, races, migration-vs-real-data hazards. Deepest on "prove it's broken." |
| **Gemini** | `gemini` | Breadth across many files at once; long context; multimodal (video/audio/images/PDF). Catches "the same mistake in twelve places." |
| **Grok** | `grok` | Product/ops/regulatory reality: does this work end-to-end for a real user, what breaks on deploy, what has no off-switch, copy that lies. Ranks by real-world impact. |

These lenses are empirical, not marketing. On a ~6,400-line review each brain surfaced a class the others entirely missed. **Give each brain a different lens in the prompt** — ask four models the same generic question and you pay four times for one answer.

---

## Model currency — never pin, always echo

**Do NOT pass `-m` / `--model` and do NOT pin version strings in prompts.** Each CLI's configured default is the source of truth, so the stack picks up new models the day the vendor ships them. Pinning is how a stack silently rots — and pinning `-codex` variants on ChatGPT-account auth returns 400.

**Expected stack (2026-10-17):** Claude on Opus 5.5 as the driver; Codex on GPT-6.1 Sol at medium effort for review (`model = "gpt-6.1-sol"`, `model_reasoning_effort = "medium"` in `~/.codex/config.toml`, codex-cli 0.161 or newer); code BUILDS go through `/codex-build`, which pins the same model. This replaces GPT-6 Astra at xhigh, retired by the owner for draining the Codex usage allowance: on Terminal-Bench 4.0 (Vals AI, 2026-10-16) GPT-6.1 Sol scores 55.1% at about $1.72 a task against Astra's 59.6% at $9.58. **Never raise the default to Astra or to xhigh, max or ultra.** If one review genuinely needs more depth, raise that single call with `-c model_reasoning_effort="high"` and say so. The model comes from each CLI's config, not a `-m` flag, so **echo what actually resolved** at the start of a session and flag any mismatch with the expected stack:

```bash
codex --version 2>&1 | head -1
gemini --version 2>&1 | head -1
grok --version 2>&1 | head -1
# Configured defaults (absent = CLI default):
grep -i '^model' ~/.codex/config.toml 2>/dev/null
```

Report it in one line: `Brains: claude opus-5.5, codex <ver> (gpt-6.1-sol, medium), gemini <ver>, grok <ver>.` If the Codex model line is not `gpt-6.1-sol`, the effort line is anything above `medium`, or you are not running on Opus 5.5, say so before routing work.
If a CLI is missing, say so once, drop that route, and continue. Don't retry it every turn.

---

## Invocation reference (verified syntax)

Each of these has a non-obvious failure mode. Use exactly these shapes.

### Codex — read-only review
```bash
codex exec -s read-only --json -o /tmp/4brain-codex.txt "<prompt>" < /dev/null 2>/dev/null \
  | grep '"type":"thread.started"'
```
- **`< /dev/null` is mandatory.** `codex exec` reads stdin *in addition to* the prompt argument and will hang forever under a non-TTY driver without it.
- Piping a diff on stdin works and is **strongly preferred for large reviews** — asking Codex to read many repo files itself can stall for 15+ minutes; a piped diff returns in a few.
- Capture `thread_id` to resume: `codex exec resume "$ID" -c sandbox_mode="read-only" ...` — **`resume` rejects `-s`**, so force read-only via `-c sandbox_mode` or it inherits config (possibly write access).
- Read the report from the `-o` file, not the JSONL stream.

### Codex — build with write access
```bash
codex exec -s workspace-write -c sandbox_workspace_write.network_access=true --json \
  -o /tmp/4brain-build.txt - <"$PROMPT_FILE" 2>/dev/null
```
- Prompt via stdin file avoids quoting bugs and the stdin hang at once.
- `--yolo` may be blocked by permission classifiers; `-s workspace-write` is safer and equivalent for this purpose. Network access is required if the agent must reach a local test database.

### Gemini — long context and multimodal
```bash
gemini -p "Analyze @path/to/file … <explicit output format>"
gemini --include-directories /tmp/work -p "… @/tmp/work/clip.mp4 …"
```
- **Auth is a deliberate, machine-level `GEMINI_API_KEY` (User env var) plus `~/.gemini/settings.json` → `security.auth.selectedType: "gemini-api-key"`.** Set up 2026-07-26 after discovering `gemini` auto-loads `GEMINI_API_KEY`/`GOOGLE_API_KEY` from ANY `.env` in its working directory tree — a review run from inside a project repo had been silently billing that project's own in-product Gemini key instead of a real CLI login, with `selectedType` pinned to `oauth-personal` making it worse (ran an OAuth eligibility check even when a valid API key was passed explicitly). Fixed by pinning `selectedType` to `"gemini-api-key"` and setting the key once at the Windows User env var level — because that makes it always-defined before any process starts, a project's own `.env` can never inject or override it (`dotenv`-style loaders only fill in undefined vars). Do NOT blank or unset `GEMINI_API_KEY` before invoking `gemini` — that was the OLD workaround from when the only source of the key was an accidental project leak; it is no longer needed and would just break this fix.
- If `gemini` reports "you must specify the GEMINI_API_KEY environment variable," the machine-level var isn't visible to the current process tree yet (Windows env var changes only propagate to processes started after the change; a long-running session needs a restart to inherit it) — treat this as a transient environment issue, not a missing-auth situation: say so once, drop the route for this run, continue with the remaining brains.
- **The `@path` must be INSIDE the `-p` string.** Passing the file as a separate argument makes the CLI dump its help screen and analyze nothing.
- `--include-directories` is required for paths outside the workspace.
- If it blocks on directory trust, set `~/.gemini/settings.json` → `{"security":{"folderTrust":{"enabled":false}}}` or prefix `GEMINI_CLI_TRUST_WORKSPACE=true`.

### Grok — independent review
```bash
grok --always-approve --sandbox read-only --disallowed-tools "edit,write" --max-turns 40 -p "<prompt>"
```
- `-p/--single` is headless single-turn: prints to stdout and exits.
- **`--always-approve` is mandatory in headless mode.** Without it every tool call waits for a TTY approval that never comes, the turn ends with exit 0 and two lines of narration, and you get no findings. Judge a run by output size and a VERDICT line, never by exit code.
- Keep inputs under the project cwd (e.g. `.4-brain-out/<run>/src/`) and reference relative paths; Grok cannot read a `C:/tmp` worktree from the project directory, and a prompt over ~30KB passed as an argument fails with `Argument list too long`.
- `--output-format json` and `--json-schema` available for structured output.
- Runs long on large diffs — background it with a generous ceiling.


### Browser: behavioural evidence (optional fifth lens)

The three brains above all read code. None of them can tell you whether the
thing works when a human clicks it. That is a separate defect class, and it is
the one that reaches the customer.

This lens is **detected, not vendored.** If [pstack](https://github.com/pstack)
is installed it ships a real Chromium harness (`/browse`, `/qa-only`) at roughly
100ms per command with screenshots. It is ~170MB, so 4-brain depends on it when
present and drops the route when it is not, exactly like a missing CLI.

```bash
# Present?
ls ~/.claude/skills/browse/SKILL.md 2>/dev/null || ls ~/.codex/skills/pstack/browse/SKILL.md 2>/dev/null
```

- Prefer `/qa-only` over `/qa` for review work: report-only, never edits the code
  under review.
- It needs a RUNNING app. Point it at a scratch/test database, never the one your
  `.env` points at. Dogfooding a "create" button against production writes
  production rows.
- Worth firing when the diff touches UI, a form, a list with pagination, or
  anything whose bug would be "correct code that does not do the job".

**All long calls:** run in the background with a 10–15 minute ceiling. A stalled brain must fail loud, never hang the turn.

---

## Media preprocessing (Gemini)

Never hand a raw long video/audio/PDF to a model. Cap it first, and always demand **timestamps, page numbers, or file:line citations** — never accept a flat summary.

```bash
yt-dlp -f "best[ext=mp4][height<=720]" "<url>" -o /tmp/4brain/in.mp4   # if a URL
ffmpeg -t 120 -i /tmp/4brain/in.mp4 /tmp/4brain/clip.mp4 -y            # cap duration
ffmpeg -i /tmp/4brain/clip.mp4 -vn -ac 1 -ar 16000 /tmp/4brain/audio.wav -y
qpdf --pages input.pdf 1-100 -- /tmp/4brain/doc.pdf                    # cap pages
```

---

## Review protocol

For anything substantial, run brains **in parallel with different lenses**, then adjudicate.

1. **Assign lenses.** Codex: correctness/concurrency/races. Gemini: cross-file sweep for a specific defect class. Grok: does it work for a real user / on deploy / legally. Claude: run the proof (typecheck, tests, build) — never delegate the proof.
2. **Demand structure.** `FINDING <n>: title / file:line / severity blocker|major|minor|info / evidence / concrete fix`, ending in an explicit verdict line.
3. **VERIFY EVERY FINDING BEFORE ACTING.** This is not optional and it is where the value is.
   - Confident, well-argued, and wrong is the normal failure mode of every brain here.
   - Check each claim against the actual code. Reject wrong ones **with a logged reason**; caving to everything defeats the cross-check as surely as ignoring it.
   - Watch for findings about code **outside the reviewed diff** — pre-existing issues are worth reporting to the user, not fixing inside an unrelated change.
   - Watch for findings that contradict the **intended spec** — "this refunds after capture" may be exactly what the design says.
   - **Adjudicate the FINDING and the FIX separately.** A brain can be right that
     something is broken and wrong about how to repair it. A proposed fix that
     scopes a query on a nullable column, for instance, silently drops rows and
     is worse than the bug it closes.

   Rejection patterns seen repeatedly, worth matching against before you act:

   | Pattern | What it looks like | How to check |
   |---|---|---|
   | Guarded elsewhere | "unscoped tenant query", `where(eq(x.id, id))` with no org filter | Read the NEXT few lines. An `if (row.orgId !== orgId) return 404` is a real guard, just not in the WHERE clause. A grep cannot see it. |
   | Fix worse than finding | Real defect, dangerous repair | Check the proposed fix's own assumptions: nullability, legacy rows, fail-open vs fail-closed |
   | Severity inflation | "compliance hole" / "blocker" | Trace downstream. If a later layer already drops the bad value, the impact is a wrong counter, not an incident |
   | Out of diff | Real, but in code this change never touches | Report it to the user; do not fix it inside an unrelated change |
   | Contradicts spec | "this refunds after capture" | Re-read the spec. It may be the design |

4. **Claude is final arbiter.** The other brains advise; they do not command.
5. **Fix once**, after all brains report, so overlapping findings collapse into one edit.
6. **Know what counts as a proof.** Claude runs it, but not everything that
   passes is evidence.
   - A grep or regex assertion proves a string is **present**. It never proves
     the code is **correct**. Pair it with the compiler.
   - Real case: a merge produced two declarations of the same interface field,
     with zero conflict markers. Four static proof suites passed, because they
     asserted the field existed. Only `tsc` caught the duplicate identifier.
   - After any large merge, re-run the typecheck before you trust a green suite.
   - Watch for a test that cannot fail: an unrun DB-backed suite, a check
     `continue-on-error`'d into a permanent pass, or a job whose timeout kills it
     so the result renders as something other than failure.

7. **Watch the builder for traded-away guards.** Distinct from "introduced a
   bug" and much harder to spot. When a brain has write access, it will sometimes
   remove a safety check to improve something cosmetic next to it, and write a
   confident comment justifying the trade. Observed: a DNC compliance gate
   deleted so a "skipped" counter could be more accurate. Nothing downstream
   re-checked the flag. Diff safety-relevant conditions specifically; do not skim
   a deletion just because the surrounding change looks like an improvement.

### Consensus mode (high-stakes, explicitly requested)
"Ask all four / before I commit to this / cross-architecture consensus" → same question to every brain, forced template:
```
Recommendation: <one line>
Blocking risks: <bullets>
Assumptions: <bullets>
Confidence: low / medium / high
Tests required to verify: <bullets>
```
Claude diffs them and adjudicates **by evidence, not by majority**.

---

## Forced routes (announce before running)

When the skill fires a route the user did not explicitly ask for, announce it in **one line first** so they can interrupt:

```
[4-brain] routing to Codex (adversarial-review) — risk path: server/billing/
[4-brain] handing off to Codex rescue — same test failed 2× in a row
```

**Risk paths** (an *active edit*, not just mention in chat): auth, billing/payments, migrations, deploy scripts, env/secrets, permissions/ACLs, infra-as-code, token handling. Verb doesn't matter if the target is irreversible: "refactor the auth middleware" and "plan the Stripe migration" both fire.

**Failure counter (hard rule, not a vibe):** 2× same test failure on the same path, 2× same command error, or 2× same edit with no progress → MUST invoke rescue with full context (failing output, what was tried, relevant files). Reset only when it passes, the goal changes, or the user says "keep trying."

---

## Output filing

Everything produced goes to `./.4-brain-out/<YYYY-MM-DD>-<slug>/`:

```
input.txt          what was asked
codex-review.md    gemini-analysis.md    grok-analysis.md
claude-verdict.md  what was accepted, rejected, and why
```

Append one line per run to `./.4-brain-out/log.md`:
```
[2026-07-26 07:00] route=4-brain-audit target=<slug> brains=codex,gemini,grok findings=30 fixed=11 verdict=green
```
That ledger is the compounding artifact — it shows which brain earns its keep on which kind of work.

Add `.4-brain-out/` to the project's `.gitignore` unless the team wants reviews committed.

---

## Stay asleep

Do not fire on: casual conversation or status checks; anything Claude can answer directly; recall/lookup questions; "save this / wrap up"; work already owned by another skill.

**When uncertain, stay asleep.** Under-firing is fine. Over-firing burns tokens and trust.
