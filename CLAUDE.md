# CLAUDE.md

## Project Quick Reference

<!-- The ONLY project-specific section. Fill in, keep to ~8 lines, link out for detail. -->
- **What this is:** <one sentence>
- **Run:** `<command>`
- **Test:** `<command>`
- **Architecture / docs:** `<path>` (source of truth — do not duplicate here)
- **Backlog:** `BACKLOG.md`

## Think Before Coding

Don't assume. Don't hide confusion. Surface tradeoffs. Before implementing:

- State your assumptions explicitly.
- Ask only when interpretations materially diverge — present the options, don't
  pick silently. For minor gaps, state your assumption and proceed.
- If a simpler approach exists, say so. Push back when warranted.

## Simplicity First

Minimum code that solves the problem. Nothing speculative.

- No features beyond what was asked. "Nice to have" is not a reason.
- No abstractions for single-use code — wait for the third use.
- No "flexibility" or "configurability" that wasn't requested.
- Handle errors that can actually occur; don't handle ones the types or call
  site already rule out.
- If you write 200 lines and it could be 50, rewrite it.
- Test: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## Surgical Changes

Touch only what you must. Every changed line traces directly to the request.

- Don't "improve" adjacent code, comments, or formatting. Don't refactor what
  isn't broken. Match existing style, even if you'd do it differently.
- If you notice unrelated dead code or bugs, mention them — don't fix them here.
- Remove imports/variables/functions that YOUR changes made unused. Leave
  pre-existing dead code alone unless asked.
- When replacing code, delete the old version. No `_old`, `_v2`, or commented-out
  blocks. Git has history.

## Before Writing Code

1. Search for an existing implementation first. Reuse is the default; extend if
   close (update its tests); replace only as an explicit separate change — never
   silently fork.
2. Read what you found completely: inputs, outputs, error paths, conventions.
3. One owner per concept. Shared logic lives in one module; all other callers
   import it, never re-implement it.
4. Reuse existing channels (fields, flags, files, return shapes) before inventing
   new ones. A new config key, sidecar file, or CLI flag is a warning sign.
5. If you create something new, justify it in one sentence in the commit message.
   If you can't write that sentence, you're reinventing.

## Goal-Driven Execution

Define success criteria. Loop until verified.

- Transform tasks into verifiable goals: "add validation" → "write tests for
  invalid inputs, make them pass"; "fix the bug" → "write a test that reproduces
  it, make it pass"; "refactor X" → "tests pass before and after".
- Never claim "tested" unless you ran it. Unit tests prove code correctness; only
  exercising the feature (browser, CLI, real invocation) proves feature
  correctness. UI-visible changes need UI verification.
- Mocks mirror real output: run the real tool once, copy its shape into the
  fixture.
- Before marking done, check output against the requirement, not what you built.

## Debugging

1. Identify the exact symptom, then trace it upstream to the component that
   introduced it.
2. Fix at the source. Never patch downstream to compensate for a broken
   upstream — workarounds mask the real problem and accumulate.
3. One root cause = one fix. Multiple symptoms sharing a cause get fixed once.
4. Reaching for a workaround, flag, or special case is a signal the design is
   wrong — say so instead of patching.

## Specs & Plans

Complex work (multi-file, multi-session, or involving design decisions) gets a
spec (what and why) and a plan (ordered, checkboxed tasks) written as files
before implementation. When an effort spans phases, split into a master spec +
master plan (phase table) with one sub-spec + sub-plan per phase, one branch/PR
per phase. Trivial work needs neither — don't generate ceremony.

Author every plan for parallel execution — the plan itself instructs it:

- Give every task an explicit Files set and Depends-on list. Express build
  order as lanes: `[Lane A ‖ Lane B] → sequential tail`.
- Two tasks are parallel-safe only if their file sets are disjoint AND neither
  depends on the other's output. Same-file tasks serialize — even non-adjacent
  edits cause churn.
- Run safe lanes as concurrent subagents; each lane runs only its own test
  scope and never runs git — the controller commits serially. Read-only work
  (review, search, verification) always overlaps freely.
- If a split forces shared-file edits or unreliable tests, keep it sequential.
  Parallelism changes scheduling, not quality gates.
- Tier models: cheaper/faster models for execution-heavy lanes (boilerplate,
  mechanical edits, search, test runs); strongest model for planning, review,
  and final verification. A cheap model never self-certifies — a stronger
  model checks the diff against the requirement.

Executing a plan:

- Explicit checkpoint / approval gate: STOP, surface the content and decisions,
  wait. Never chain into the next phase unasked.
- Tick `- [ ]` checkboxes alongside the work. If execution diverges, update the
  spec/plan first, then resume — don't bolt deviations on silently.
- Leave state resumable: a fresh session reading the plan should know the exact
  next action.

## Errors & Security

- No silent failures: exit non-zero on error, never swallow exceptions, never
  return partial results without flagging what's missing.
- Error messages state what went wrong AND what to do about it.
- Validate at system boundaries (user input, external APIs); trust internal code.
- Never fabricate data, results, or citations. Say "I don't know" or go check.
- Secrets live in `.env` (gitignored). Never commit, log, or print them.
- Parameterized queries only. Never interpolate input into SQL or shell commands.

## Git

- Small, focused commits — one logical change each. Prefixes: `feat:`, `fix:`,
  `test:`, `docs:`, `refactor:`, `chore:`.
- Never commit directly to `main`. Branch (`<type>/<short-desc>`) → PR → user
  approves and merges. Don't self-merge, force-push, skip hooks, or amend
  published commits without explicit instruction.
- Pre-push checklist: tests pass; full staged diff read (debug prints, TODOs,
  dead code, accidental deletions); no secrets, generated artifacts, or files
  >1MB staged; imports/lint clean.

## Deferred Work

Work discovered mid-task that can't be done now (bugs, ideas, open questions) is
captured immediately — never fixed as scope creep, never silently dropped.

- Tracker first: if the project has an issue tracker (GitHub Issues, Linear,
  Jira), it is the system of record — file items there (`gh issue create`) and
  check it before proposing new work.
- Otherwise `BACKLOG.md` at repo root: active items only, one capture point (no
  TODO.md/BUGS.md shadows). `- [ ] **Title** — 1-2 line context, file pointer.`
- Closing an item = delete its entry in the closing commit, resolution in the
  commit message. Git history is the audit trail — no Done section, so the
  file never grows.
- In parallel runs, only the controller edits the backlog.

## Keep This File Lean

No history, architecture diagrams, env listings, or layout maps — they go stale
and cost context every turn. Put them in README/docs and pointer here.
