### Description

<!-- Please describe your pull request. Also included any issues this pr will be fixing. -->

### Your checklist for this pull request

🚨Please review the [guidelines for contributing](https://maester.dev/docs/contributing) to this repository.

- [ ] Read the guidelines for contributions

#### PRs related to all code

- [ ] Before you submit the PR, run the tests locally by running `/powershell/tests/pester.ps1`
- [ ] After submitting, verify the tests are still passing on your PR in GitHub (the tests are run across all platforms).

#### PRs related to Maester Tests

If you are contributing a test or making updates to a test please verify these.

- [ ] Check that the unique ID you want to use is not already picked. See [Pick next Maester test sequence number](https://github.com/maester365/maester/issues/697)
- [ ] Add Test with your .ps1 and .md-file (make sure .ps1 file is encoded with "UTF8 with BOM") `.\powershell\public\maester...`
- [ ] Add your new test-function to a corresponding .test.ps1 file `\tests\Maester..*.test.ps1`
- [ ] Add your new test-function to 'FunctionsToExport'-List `.\powershell\Maester.psd1`
- [ ] Add test Id, Severity and Title to "maester-config.json" file `.\tests\maester-config.json`
- [ ] Add website documentation for test with name of "testId.md" `.\website\docs\tests\maester`
- [ ] If Invoke-Maester parameters are changed, update the GitHub action to use the new parameters.

### Review

We will try to review your pull request as soon as possible. If you have any queries or need any help please jump on [Discord](https://discord.maester.dev/). We really appreciate your contributions!

<!-- While your wait for a review, why not try to spread some Maester love on social media? -->

💖 Thank you!
