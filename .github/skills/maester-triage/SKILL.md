---
name: maester-triage
description: >-
  Label and re-label Maester pull requests, issues and discussions with the repository's
  label rubric, so reviewers can filter the queue by status, type and product. Use when
  asked to triage, label, tag or "update the status of" PRs, issues or discussions in
  maester365/maester, to re-check whether a PR is waiting on its author or a reviewer, or to
  find items that have no status. Covers the label families in .github/labels.json, how to
  choose each one from the diff, reviews and comments, and how to apply them with gh.
metadata:
  audience: "Maintainers and reviewers"
  summary: "The label rubric for PRs, issues and discussions, and the steps for applying it."
---

# Maester triage

Labels on maester365/maester follow one rubric so that anyone can filter the queue, for
example `is:pr is:open label:"status: needs review" label:"product: entra"`. This skill is that
rubric and the steps for applying it. The label list itself, with colours and descriptions, is
[`.github/labels.json`](../../labels.json). Never invent a label that is not in that file.

## What you can be asked to do

| Request | Scope |
| --- | --- |
| "triage", "update the labels" | Every open PR, issue and discussion |
| "triage PRs" / "issues" / "discussions" | That kind only |
| "triage #1234" | That item only |
| "what has no status?" | Report open items with no `status:` label; change nothing |
| "sync the labels" | Run `./build/github/Sync-GitHubLabels.ps1` (dry run first) |

## How to run

1. **Collect.** Use `gh` (or the GitHub tools you have). Read each item's title, body, labels,
   author, draft state, linked items, reviews, comments and, for a PR, its changed files, CI
   checks and mergeable state. For a PR, `gh pr view N --json` with `files,reviews,comments,
   commits,mergeable,statusCheckRollup,isDraft,labels,author,body`. That does not include
   inline review threads, so also read them through GraphQL (`pullRequest.reviewThreads`, every
   page, with `isResolved` and each thread's comments). An unresolved thread in which a
   maintainer asks for a change counts as a change request. For discussions, GraphQL
   (`repository.discussions`).
2. **Find the maintainers.** A maintainer is anyone with write, maintain or admin permission:
   `gh api repos/maester365/maester/collaborators/<login>/permission --jq .permission`. Cache
   the answer per login. Bots (`[bot]` logins, CodeRabbit, Copilot) are never maintainers, and
   their reviews never set a status.
3. **Decide the labels** for each item with the rules below. Labels from other families than
   the ones below, and labels a maintainer added by hand in a family you only add to
   (`flag`, `resolution`), are left alone.
4. **Show the plan before writing.** Print a table: item, current labels, labels to add, labels
   to remove, and a reason of a few words for each status. Unless the request said to apply
   directly, stop and ask for approval.
5. **Apply.** PRs and issues: `gh pr edit N --add-label "..." --remove-label "..."` and
   `gh issue edit`. Discussions: the `addLabelsToLabelable` and `removeLabelsFromLabelable`
   GraphQL mutations with the discussion's node id and the label ids from
   `repository.labels`. Batch per item; never one call per label.
6. **Report** what changed and anything you could not decide, as a short list.

Triage only labels. It never comments, reviews, approves, closes, merges, converts or edits an
item's text. If an item looks like it should be closed (superseded, duplicate, already fixed on
`main`), say so in the report and let a maintainer do it.

## The families

Each open PR and issue gets **exactly one** `status:` label and **one type**. Announcements, Polls and Show and tell
discussions get no type, and a discussion's status follows its own table below. When an item
carries a second type or an old label the rubric replaces, remove it. `product:`, `suite:` and flags are added only when they are true.

### Status (exactly one)

Pull requests. Take the first rule that matches.

| Label | When |
| --- | --- |
| `status: in progress` | The PR is a draft. |
| `status: blocked` | It cannot merge until another open PR or issue lands first, as the PR or a maintainer says. A PR stacked on another PR's branch is **not** blocked by that alone: it can be reviewed now. |
| `status: changes requested` | A maintainer's latest review is "changes requested", or a maintainer's latest comment or review asks the author for changes, and the author has not pushed a commit since that addresses it. This wins over an open question in the same review. |
| `status: needs decision` | A question only a maintainer can settle stops it from merging (a taxonomy key, a new attribute format, which of two overlapping PRs goes in, pass vs fail semantics), nobody has settled it, and no author fixes are outstanding. The question must be written on the PR, or named by the maintainer who asked for this triage run; name it in your report. |
| `status: ready to merge` | A maintainer approved the current head commit (the approval is not dismissed and no commit other than a merge from `main` came after it), no maintainer asked for more after that approval, the required checks pass, and it has no conflicts. A substantive push after the approval makes it `status: needs review` again. |
| `status: needs review` | Anything else, including a PR whose author pushed fixes after changes were requested. That push hands it back to the reviewer. |

"The author pushed" includes co-authors and agents committing for the author. When the PR's
author is a maintainer, their own pushes count the same way. A merge commit from `main` on its
own is not a response; look for a commit that changes the files the review was about.

Issues. Take the first rule that matches.

| Label | When |
| --- | --- |
| `status: awaiting confirmation` | A PR that closes it has merged, or a maintainer said the fix shipped and is waiting for the reporter. Suggest closing it in the report. |
| `status: blocked` | It waits on another open item, an unreleased feature, or an upstream product or module fix. |
| `status: needs info` | A maintainer's latest comment asks the reporter a question and the reporter has not answered. |
| `status: needs decision` | A maintainer has to decide whether or how to do it, including a reporter asking a maintainer to choose (a severity, a default, an approach). |
| `status: in progress` | An open PR closes it (a closing keyword such as "fixes #N", or the Development sidebar), or it has an assignee and activity in the last 90 days. A mention such as "related to #N" or "tracked in #N" does not count. |
| `status: accepted` | A maintainer opened it, labelled it, confirmed the bug or agreed to the feature, and nobody has started it. |
| `status: needs triage` | No maintainer has engaged yet, **or** the reporter answered a maintainer's question and it is the maintainers' turn again. |

A maintainer opening, labelling or assigning an issue counts as engaging with it. Skip pinned
issues (such as the MT test ID reservation thread, #697): they are permanent and take no status.

Discussions. Take the first rule that matches; a discussion that matches none gets no status.

| Label | When |
| --- | --- |
| (none) | It is closed, an answered Q&A, an Announcement, a Poll or Show and tell, or a reply resolved it (the author confirmed it works, or the question was fully answered by anyone). For a resolved Q&A, suggest marking that reply as the answer; for a resolved General thread, suggest closing it. |
| `status: tracked` | A maintainer linked an issue or PR that carries the work, or that issue or PR links back to the discussion. A matching title alone does not count: suggest the link in the report. |
| `status: needs info` | A maintainer's latest comment asks the author a question and the author has not answered. |
| `status: accepted` | An Idea a maintainer agreed to ("moving to backlog", "PRs welcome"), or one a maintainer posted that no maintainer has objected to. Suggest converting it to an issue so the work is tracked. |
| `status: needs decision` | An Idea no maintainer has accepted or declined yet. |
| `status: needs reply` | A question or problem report that no maintainer has replied to and that is not resolved. |

Remove a status label from any discussion that matches the first row.

### Type (exactly one)

| Label | When |
| --- | --- |
| `new test` | The PR adds at least one new check (a new `tests/**/Test.<ID>.ps1`), or the issue or idea asks for one. A PR that also fixes other things is still `new test`. |
| `bug` | Fixes, or reports, behaviour that is wrong. A check with the wrong result (false pass or false fail) is a `bug`. |
| `enhancement` | A new capability or an improvement to an existing one that is not a new check, including changes to a check's attributes (severity, product, ResourceType and so on). |
| `documentation` | Only docs or the website's content change, or the issue is about docs. |
| `maintenance` | Refactoring, build, CI, dependency or repository housekeeping with no user-visible change. |
| `question` | An issue or discussion asking how to use Maester. Not for PRs. |

Conventional-commit prefixes in a PR title are a hint (`feat` → `enhancement` or `new test`,
`fix` → `bug`, `docs` → `documentation`, `chore`/`ci`/`build`/`refactor` → `maintenance`), but
the diff decides.

### Product (zero to three)

Use the product keys from `powershell/assets/MaesterTaxonomy.psd1`: `product: entra`,
`exchange`, `defender`, `intune`, `purview`, `sharepoint`, `teams`, `microsoft-365`, `azure`,
`azure-devops`, `github`, `ad`, `copilot-studio`, `fabric`. For a PR that adds or changes checks, count the
`Product` of each check it touches and keep the three products with the most checks, dropping
any product with a single check when the PR touches more than three products. For an issue or
discussion, the product the report is about. Engine changes that are not specific to one service
get no product.

### Suite (zero or more)

A proposal for a new benchmark gets no suite label until that suite exists; mention it in the
report so a maintainer can add one to `.github/labels.json`.

`suite: asd`, `suite: cis`, `suite: cisa`, `suite: eidsca`, `suite: orca`: the PR adds or changes checks in
`tests/<suite>/**` or changes that suite's generator under `build/<suite>/**`, or the item is
about that benchmark's mapping, content or permissions. A one-line attribute alignment in
another suite's check does not add that suite. The MT checks under `tests/maester/**` and the AD
checks under `tests/ad/**` have no suite label; `product:` already covers them.

### Flags (add when true; remove only the ones you can compute)

| Label | When | Who sets it |
| --- | --- | --- |
| `needs rebase` | `mergeable` is `CONFLICTING`. Remove it when the conflict is gone. | Triage |
| `generated` | Every changed file is generated, as in the bot PRs that regenerate test docs. Generated files are `website/docs/tests/**`, `website/versioned_docs/**`, `**/fixtures/golden/**`, `website/src/data/test-builder.json`, `packs/*/catalog.json`, the upstream-generated suites `tests/eidsca/**`, `tests/orca/**` and `powershell/internal/generated/**`, the agent and skill copies `.claude/agents/**`, `.claude/skills/**` and `website/docs/agents-and-skills.md` that `build/github/Update-AgentFiles.ps1` writes, `*.dll`, lock files, and any other file whose first lines contain both "Generated by" and "Do not edit". | Triage |
| `breaking change` | It removes or renames a public cmdlet, parameter, output field or test ID, changes a default, removes a check from the default run, or changes what a check considers correct. Fixing a check so that it matches its documented behaviour is a `bug`, not a breaking change. On an issue: the request or the reported fix would need such a change. | Triage adds; only a maintainer removes |
| `attribute-review-override`, `good first issue`, `help wanted` | Maintainer judgement. | Never set or remove |

### Resolution (maintainers only)

`duplicate`, `superseded`, `wontfix` and `invalid` explain why something was closed. Triage
never sets or removes them; it suggests them in the report.

## Checks before you report

- Every open PR and issue you touched has exactly one `status:` and one type label.
- No label you added is missing from `.github/labels.json`.
- For each `status: changes requested`, you can name the maintainer review or comment, and you
  checked that no author commit came after it.
- A maintainer's approval followed by a later maintainer ask is not an approval.
- For each `status: needs decision`, you can state the open question in one line.
