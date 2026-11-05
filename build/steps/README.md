# Step catalogue tooling

These scripts keep the defender's path catalogue (`powershell/assets/steps`) in line with Microsoft Learn. The
design is in `docs/proposals/defenders-path.md`, section 13. They read nine public mirrors of Learn that
[merill/learn-mirror](https://github.com/merill/learn-mirror) keeps in git: `merill/entra-docs-mirror`,
`intune-docs-mirror`, `defender-docs-mirror`, `security-docs-mirror`, `purview-docs-mirror`, `teams-docs-mirror`,
`sharepoint-docs-mirror`, `exchange-docs-mirror` and `windows-server-docs-mirror`.

None of them writes to the catalogue. A maintainer reads what they find and edits the catalogue by hand, in
Maester's own words.

| Script | What it does |
| --- | --- |
| `Update-MtLearnMirror.ps1` | Clones or updates the mirrors into `build/steps/.cache` (ignored by git) and writes the URL-to-file index. Asks Learn where each linked URL that no mirror has under that key now goes, and caches the answers for 30 days |
| `Find-MtStepCandidate.ps1` | Pulls the prerequisite sections and the sentences about order from every page that a check guide or a step source links, with the mirror file and line, into `step-candidates.json` for review. `-SuggestNote` also asks a model for Note text, off by default |
| `Test-MtStepSource.ps1` | Lists the step sources whose page changed since its `Reviewed` date. Exits 1 when any needs review |

The functions they share are in `helpers/`, one per file.

## Running them

```powershell
./build/steps/Update-MtLearnMirror.ps1          # about 3 minutes the first time, then seconds
./build/steps/Test-MtStepSource.ps1             # which sources changed since they were reviewed
./build/steps/Test-MtStepSource.ps1 -Step 'entra.*' -ShowDiff
./build/steps/Find-MtStepCandidate.ps1 -Links Catalog
```

The scripts need PowerShell 7.4 or later and git. Only `Update-MtLearnMirror.ps1` goes to the network (GitHub
for the mirrors, Learn for redirects); the others read the cache. In the blobless clones git fetches an older
version of a page when `Test-MtStepSource.ps1` compares one.

## The weekly issue

`.github/workflows/step-sources.yaml` runs `Test-MtStepSource.ps1` every Monday and on demand. While any source
needs review, one issue labelled `step-sources` stays open, and each run rewrites its list. For each source it
lists:

- **Changed**: the page's text changed since `Reviewed`. Read the diff, update the step if Learn changed what
  comes first, and set `Reviewed` to the date you read it.
- **New**: the page's file is newer than `Reviewed` (the page moved or was published since). Re-read it.
- **NoBaseline**: the mirror starts after `Reviewed`, so it can't show what changed. Re-read the page.
- **NotFound**: no mirror has the page any more. Find where Learn moved it, or another source.
- A redirect or a wrong `Mirror`: cite the URL Learn now uses, or the mirror that holds the page.

When every source is current, the run closes the issue. It never opens pull requests.

## How a change is detected

- `Reviewed` covers the whole day in UTC: the baseline is the mirror's last commit on or before 23:59:59 that day.
- Only the page's body counts. The mirrors commit once per crawl, and a crawl after Learn changes its metadata
  rewrites the front matter of thousands of pages. A commit that changes only front matter is not a change.
- The diff link names the file's anchor on GitHub's commit page. A compare page over a large crawl can be too big
  for GitHub to show one file, so each commit is linked as well, with the file's history.

## Redirects

Check guides link many pages by an old URL (`mem/intune/...`, `microsoft-365/security/...`,
`azure/active-directory/...`). Learn answers a HEAD request for those from a cache that often leaves the redirect
out, so `Update-MtLearnMirror.ps1` sends a GET that reads only the headers, asks for Markdown as learn-mirror does,
and follows the redirect one hop at a time. Answers are kept in `.cache/redirects.json`. The update also lists the
linked pages that Learn answers 404 for, which are broken links in the check guides.
