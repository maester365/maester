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

### Submitting a Pull-Request

When submitting a PR for changes in `/report/src` you can skip updating the `/powershell/assets/ReportTemplate.html` artifact. The [build-maester-report-template](https://github.com/maester365/maester/blob/main/.github/workflows/build-maester-report-template.yaml) workflow automatically builds and includes an updated ReportTemplate as part of the module publish pipeline.
