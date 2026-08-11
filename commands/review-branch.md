Review the current branch against its base branch.

The review is multi-pass: specialist reviewers run in parallel, then every finding they
produce is independently validated before it reaches the report. Findings that cannot be
validated are discarded.

**Agent assumptions (applies to you and to every subagent you launch):**

- All tools are functional and will work without error. Do not test tools or make
  exploratory calls. Make this clear to every subagent you launch.
- Only call a tool if it is required to complete the task. Every tool call should have a
  clear purpose.
- Subagents receive instructions and context only. They do not write to `.reviews/`; you
  write the final report yourself in step 11.

Create a todo list before starting, then follow these steps precisely.

## 1. Determine the base branch

A review against a stale base is worse than no review: it drags in every upstream change the
local base is missing and reports files the branch never touched. **The base is always the
remote-tracking ref, refreshed first — never the local branch.**

First, find the base branch *name*. Usually `main`, but it may be `master`. Stop at the first
hit:

```sh
if git rev-parse --verify --quiet refs/remotes/origin/main >/dev/null; then echo main
elif git rev-parse --verify --quiet refs/remotes/origin/master >/dev/null; then echo master
elif git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null; then :
elif git rev-parse --verify --quiet main >/dev/null; then echo main
elif git rev-parse --verify --quiet master >/dev/null; then echo master
fi
```

`git symbolic-ref` returns something like `origin/main` — strip the `origin/` prefix. If every
check fails, stop and say the base branch could not be determined. Do not write a review file.

Call that name `<name>`. Now refresh it and resolve the ref to diff against:

```sh
git fetch origin <name> --quiet
```

- **Fetch succeeds** — `<base>` is `origin/<name>`. Use it everywhere below.
- **Fetch fails** (no `origin` remote, offline, auth) — fall back in this order: `origin/<name>`
  if that ref exists locally, otherwise the local `<name>`. Either way the base may be behind
  the real upstream, so record the reason and carry it into the report header in step 11.

Never silently substitute the local branch for `origin/<name>`. If you end up on a local ref,
that is a caveat the report must state.

## 2. Pin the revisions under review

The branch can move while the review runs — a review that mixes findings from two different
HEADs is not trustworthy. Pin both ends now:

```sh
git rev-parse <base>          # -> <base-sha>
git rev-parse HEAD            # -> <head-sha>
git status --porcelain        # uncommitted changes?
```

Everything from here on diffs `<base-sha>...<head-sha>`, not `<base>...HEAD`. Pass both shas
to every subagent explicitly; they must not re-resolve the base or read `HEAD` themselves.

Two things to check and carry into the report header:

- If `git status --porcelain` is non-empty, the working tree is dirty. The review covers
  committed work only; say so in the header.
- Re-run `git rev-parse HEAD` just before writing the report in step 11. If it no longer
  matches `<head-sha>`, commits landed mid-review and are **not** covered — say so in the
  header, naming the sha that was reviewed.

## 3. Gather context

Run:

- `git diff <base-sha>...<head-sha> --stat` — the list of changed files
- `git log <base-sha>..<head-sha> --oneline` — the commit messages

The commit messages are a signal of author intent. Pass them to every subagent you launch;
they are what stops a reviewer from flagging a deliberate choice as a mistake.

Sanity-check the scope before going further. If the diff spans far more files or commits than
the commit list explains — hundreds of files against a handful of branch commits — the base is
almost certainly wrong. Do not review it. Stop, report what you resolved (`<base>`,
`<base-sha>`, the commit and file counts) and say the base looks wrong.

If the diff is empty, stop and say the branch has no changes against `<base>`. Do not write a
review file.

Exclude `.reviews/` from the set of files under review — those are previous reports, not code.

## 4. Identify the ticket, if the branch names one

Run `git rev-parse --abbrev-ref HEAD`. Branches created by `worktool` are shaped
`<prefix>/<ticket>/<task>`. If the branch splits into **three or more** `/`-separated
segments, read it as one:

- `ticket` — the second segment
- `task` — everything after the second `/`, joined back together

Split on position only. The task may itself contain slashes (`me/SOM-123/add/retry/logic` is
ticket `SOM-123`, task `add/retry/logic`), so do not assume exactly three segments. Do not
assume any particular ticket-id format — it is unvalidated free text. Do not try to match the
first segment against a username; that prefix is user-configurable.

If the branch has fewer than three segments, there is no ticket. Skip this step and the next,
and continue with the commit messages alone.

## 5. Fetch ticket context, if a notes MCP is available

Optional and entirely best-effort. If tools named `search_notes`, `neighborhood` and
`read_note` are available under **any** MCP server namespace — the server name varies by
vault, so match on the tool name, not the namespace — use them to find out what the ticket
is about:

1. `search_notes` for the ticket id.
2. If that returns nothing, `search_notes` again for the ticket id together with `ticket`.
3. On the best match, `neighborhood` for correlated context, then `read_note` on the few
   most relevant notes.

Rules:

- **If no such tools are available, skip this step silently.** Do not report it, do not ask
  the user, do not suggest installing anything. This is the normal case.
- Keep it bounded — a handful of note reads, not a crawl of the whole vault.
- Notes may be stale or aspirational. Where they conflict with the code or the commit
  messages, the code wins.

Condense what you found into a short ticket-context blurb: what the ticket asks for and any
constraints it states. This gets passed to the reviewers alongside the commit messages.

## 6. Locate guidance files

Launch one subagent to return a list of file **paths only** (not their contents) for all
relevant agent guidance files:

- The root `CLAUDE.md` and/or `AGENTS.md`, if either exists
- Any `CLAUDE.md` or `AGENTS.md` in directories containing files modified by this branch

## 7. Summarize the changes

Launch one subagent to read the diff and return a summary of what the branch does. This
becomes shared context for the reviewers in step 8.

## 8. Review in parallel

Launch four subagents in parallel. Give each one the commit messages from step 3, the ticket
context from step 5 if there is any, the summary from step 7, and the guidance-file paths
from step 6. Each subagent runs `git diff <base-sha>...<head-sha>` itself rather than
receiving the diff inline — always those pinned shas, never `<base>...HEAD`.

Each returns a list of findings. Every finding must carry: the file, the line, a severity
of CRITICAL / HIGH / MEDIUM / LOW, a description, and the reason it was flagged (e.g.
"AGENTS.md adherence", "bug", "missing test").

**Reviewer 1 — guidance compliance.** Audit the changes against the guidance files. When
evaluating a file, only consider guidance files that share a path with it or sit in a parent
directory. Quote the exact rule being broken; if you cannot quote it, do not flag it.

**Reviewer 2 — bugs and logic, diff-only.** Scan for bugs using the diff alone, without
reading extra context. Flag only significant bugs; ignore nitpicks and likely false
positives. Do not flag anything you cannot validate from the diff itself.

**Reviewer 3 — security and correctness in the new code.** Look for problems in the code
this branch introduces: injection, XSS, broken authentication or authorization, exposure of
secrets or sensitive data, CSRF, SSRF, unsafe deserialization, and incorrect logic. You may
read surrounding files for context, but only flag issues that fall within the changed code.

**Reviewer 4 — tests, performance, maintainability and ticket scope.** Cover test coverage
gaps for the newly introduced behaviour, performance concerns (algorithmic complexity,
allocations in hot paths, N+1 queries, unnecessary I/O), and maintainability problems a
senior engineer would raise in review. Every finding must name a specific, actionable change.
Generic advice is not a finding.

If ticket context was found in step 5, this reviewer also owns scope: flag a requirement the
ticket clearly states that the branch does not implement, or changes that clearly fall
outside the ticket. Only this reviewer raises scope findings, so the other three do not all
report the same thing.

The ticket context is given to every reviewer primarily as author intent — its main job is to
stop deliberate choices from being flagged as mistakes.

Reviewers 1, 2 and 3 hold a high bar: **only high-signal issues.** Flag an issue where the
code will fail to compile or parse, will definitely produce wrong results, or clearly and
unambiguously violates a quoted guidance rule. If you are not certain an issue is real, do
not flag it. False positives erode trust and waste reviewer time.

Reviewer 4 is the advisory lane and may raise judgement calls, but each must still be
concrete and tied to code this branch changed.

## 9. Validate every finding

For each finding from step 8, launch a subagent in parallel to validate it. Give each the
commit messages, the ticket context if there is any, and the finding. Its job is to read the
actual code and confirm, with high confidence, that the finding is real. Validation criteria
differ by class:

- **Bugs and security issues** — confirm the code path is reachable and that the stated
  failure actually occurs. For example, if "variable is not defined" was flagged, verify that
  is genuinely true in the code.
- **Guidance violations** — confirm the rule is in scope for that file and is actually
  violated.
- **Tests, performance and maintainability** — confirm it concerns code this branch changed,
  is not already handled elsewhere, and names a specific improvement.
- **Ticket scope** — confirm the ticket *explicitly states* the requirement, and quote it. If
  the requirement can only be inferred from the ticket, it is not a finding. Notes go stale;
  this check is what keeps an outdated ticket from generating noise.

Every finding that survives must resolve to a concrete `file:line` that exists on disk.

## 10. Filter and deduplicate

Drop every finding that was not validated in step 9. Merge findings that describe the same
issue — one entry per unique issue, no duplicates.

## 11. Write the review

Create the output directory if missing: `mkdir -p .reviews`

Write the full review to `.reviews/$(date +%Y-%m-%dT%H-%M-%S).md`. Open it with a header
stating exactly what was reviewed, so a reader can tell at a glance whether the review is
still current:

```
Base: <base> @ <base-sha>
Head: <head-sha> (<branch name>)
Files: <n> changed, <n> branch commits
```

Add a line for each caveat that applies — the fetch failed and the base may be stale, the base
fell back to a local ref, the working tree was dirty, or HEAD moved after `<head-sha>`. If
none apply, leave them out.

Then one section per file that **has** at least one surviving finding:

---
## <filename>

**HIGH** — `path/to/file.go:42` Description of the finding and what to do about it.

---

Rules for the output — the Neovim browser parses this file, so the format matters:

- Rate each finding **CRITICAL** / **HIGH** / **MEDIUM** / **LOW**.
- Keep the header above the first `---`, and put no `---` inside it.
- Reference specific issues as `path/to/file.go:42`, using paths **relative to the repository
  root**, so they can be navigated directly in the editor. A path that does not resolve from
  the repo root cannot be opened.
- Separate file sections with `---` on its own line. Do not use `---` anywhere inside a
  section.
- Use `## <filename>` as the section header, one per file with findings.
- **Only files with findings get a section.** A clean file is not worth a line — no "No issues
  found.", no empty section, no roll-up list of the files that were clean. The reader scrolls
  the report to find work to do, and every section that contains none is noise between the
  ones that do. A branch touching 40 files with 3 findings produces 3 sections.
- If nothing survived validation for the whole branch, write the header followed by a single
  line: `No findings.` Do not list the reviewed files.

Finally, print a short summary to the terminal: the base ref and sha the branch was reviewed
against, the count of findings by severity, any caveat from the header, and the path of the
review file. Nothing else — do not post the findings anywhere else.

## False positives — do not flag these

Apply this list in both step 8 and step 9:

- Pre-existing issues, i.e. anything not introduced by this branch
- Something that appears to be a bug but is actually correct
- Pedantic nitpicks that a senior engineer would not flag
- Issues that a linter will catch (do not run the linter to verify)
- Issues explicitly silenced in the code, e.g. via a lint ignore comment
- Speculative problems that depend on inputs or state you have no evidence of
