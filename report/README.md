# Maester Test Report

This folder contains the test report for the Maester project.

Vite and `vite-plugin-singlefile` generate the self-contained HTML template used by
`Get-MtHtmlReport`. The production bundle uses Preact's React-compatible runtime.

## Developer guide

### Pre-requisites

- [Node.js](https://nodejs.org/en/download/) version 20.0 or above (which can be checked by running `node -v`). You can use [nvm](https://github.com/nvm-sh/nvm) for managing multiple Node versions on a single machine installed.
- When installing Node.js, you are recommended to check all checkboxes related to dependencies.

### First time run

Open terminal window and navigate to /report folder and run the following command to install all dependencies:

```shell
npm install
```

### Development

To start the development server, run the following command:

```shell
npm run dev
```

### Build

Once you are done with making updates to the report, you can build the project to create the .html template and copy it over to the /powershell folder.

To build the project, run the following command:

```shell
npm run build
```

- This will generate the `index.html` file in the `/dist` folder.
- Copy it to the /powershell/assets folder and rename it to ReportTemplate.html (overwrite the existing file).

```powershell
Copy-Item ./dist/index.html ../powershell/assets/ReportTemplate.html -Force
```

- Now PowerShell will package and use the new report template.

### Updating the sample data in the report

When making updates to the report, use the matching JSON report output as sample
data. Replace the `testResults` object in `/report/src/lib/testResults.ts`; the
development server loads this fixture directly. Production HTML reads injected JSON
from its dedicated data element, so generated HTML is not the source fixture.

The sample has the shape of a Maester 3.0 result with the report fields (`Frameworks`, `Packs`,
`Previous`, and `Fields` and `ShimOf` on rows; see `website/docs/result-schema.md`). Each test that ships
with Maester has typed attributes (`Product`, `Feature`, `Area` and so on), and the top-level `Taxonomy`
gives their display names. It also has synthetic rows so every view has data: ASD Essential Eight tests,
part of the Zero Trust Assessment pack, a community pack and a previous run.
`/report/src/lib/testResultsLegacy.ts` keeps a Maester 2.x result, which has free-text categories and tags
and none of the attributes. The report has to render both.

Add one of these to the address of the development server to check other kinds of run:

| Address | Shows |
| --- | --- |
| `http://localhost:5173/?sample=2x` | A Maester 2.x result |
| `http://localhost:5173/?sample=one` | A run of one test (the report shows the test itself) |
| `http://localhost:5173/?sample=suite` | A run of the CIS suite |
| `http://localhost:5173/?sample=tenants` | A merged result of five tenants (`Merge-MtMaesterResult`), which opens on the page that compares them |

### How the report is put together

- `src/lib/model.ts` turns a result into what the views use: rows with every field, counts, the ranking of
  failures, framework coverage, packs and the changes since the previous run.
- `src/components/report/views.ts` lists the views in the sidebar. A view is listed only when it has
  something to show, so a small run gets a short sidebar. A pack's view is built from its rows' `Fields`,
  so a new pack needs no code.
- `src/pages/report/` has one file per view; `src/components/report/` has the shell, the test detail
  (header and tabs) and the shared lists.
- `src/styles/report.css` holds the design tokens (shared with maester.dev) and every `mt-` class. The
  older pages (config, system, affected objects, exports) still use Tailwind.
- Microsoft's product and feature icons are not embedded: the report loads them from maester.dev, and the dev server
  serves them from `website/static/report-icons/v1` (see the README there for sources and terms; never change a file
  in `v1`, since generated reports keep asking for it). `src/lib/featureIcons.ts` maps features to icons.

### Submitting a Pull-Request

When submitting a PR for changes in `/report/src` you can skip updating the `/powershell/assets/ReportTemplate.html` artifact. The [build-maester-report-template](https://github.com/maester365/maester/blob/main/.github/workflows/build-maester-report-template.yaml) workflow automatically builds and includes an updated ReportTemplate as part of the module publish pipeline.
