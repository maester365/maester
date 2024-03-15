---
sidebar_position: 5
title: Contributing
---

# Contributing

## Contributing to docs

Simple edits can be made in the GitHub UI by clicking the 'Edit this page' at the bottom of each page or you can browse to the [docs](https://github.com/maester365/maester/tree/main/docs/docs) folder on GitHub.

For more complex changes, you can fork the repository and submit a pull request.

### Running documentation locally

The [Maester.dev](https://maester.dev) website is built using [Docusaurus](https://docusaurus.io/).

Follow the guide if you want to run the documentation locally and view changes in real-time.

#### Pre-requisites

[Node.js](https://nodejs.org/en/download/) version 18.0 or above (which can be checked by running node -v). When installing Node.js, you are recommended to check all checkboxes related to dependencies.

#### Installation

When running the documentation for the first time, you will need to install the dependencies. This can be done by running the following command in ./docs folder.

```
npm install
```

#### Starting the site

While in the ./docs folder run the following command to start the site locally. This will start a local server and open the site in your default browser to http://localhost:3000/

```
npm start
```

#### Editing content

You will now be able to edit add and edit markdown files in the ./docs/docs folder and see the changes in real-time in your browser.

- Read the [markdown documentation](https://docusaurus.io/docs/markdown-features) for more information on some of the custom markdown features available.
- You can search for icons at [Iconify](https://icon-sets.iconify.design/) and include them in the markdown. See the [Daily Automation](https://measter.dev/docs/automation/) page for examples.
- The `Command Reference` section is auto-generated. To update the documentation for this, the .ps1 file for the command needs to be updated with comment-based documentation.

## Maester Developer Guide

### Simple debugging

- Set a breakpoint anywhere in the code and hit F5
- The launch.json has been configured to re-load the module and run Invoke-Maester.ps1
- Change the Tag filter in Invoke-Maester.ps1 to run just the tests file you need.

### Manual editing

- Load the PowerShell module. This needs to be done anytime you make changes to the code in src.
  - `Import-Module ./src/Maester.psd1 -Force`
- Run the tests
  - `./tests/Invoke-Maester.ps1`
