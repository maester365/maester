# Description
<!-- Please provide a detailed description of your pull request here. You can explain what enhancements are being added or which issues this PR will fix.-->



<!-- End Description -->

## Contribution Checklist

Before submitting this PR, please confirm you have completed the following:

- [ ] 📖 Read the [guidelines for contributing](https://maester.dev/docs/contributing) to this repository.
- [ ] 🧪 Ensure the build and unit tests pass by running `/powershell/tests/pester.ps1` on your local system. (See the [documentation](https://maester.dev/docs/contributing#before-creating-the-pull-request) for more details.)

Please expand and verify these steps if you are contributing a new or changed Maester test.
<details>
<summary>
Maester Test PR Checklist ⤵️
</summary>

- [ ] 🔢 Pick a unique test ID that has not already been used. [Pick next Maester test sequence number](https://github.com/maester365/maester/issues/697) and add yours to the list.
- [ ] 📔 Add the Pester test (.ps1) and documentation (.md) files in `./powershell/public/maester/{Category}/...` (Make sure the .ps1 file is encoded with "UTF8 with BOM.")
- [ ] 📜 Add your new test function to a corresponding script file in `/tests/Maester/{Category}/{TestName}.Test.ps1`
- [ ] 🗄️ Add the new test Id, title, and severity to the "maester-config.json" file in `./tests/maester-config.json`
- [ ] 📋 Add the name of your new test script function to the 'FunctionsToExport' list in the module manifest (`./powershell/Maester.psd1`)
- [ ] 🌍 Add or update documentation for the test on the web site `./website/docs/tests/maester/{TestName}.md}`
- [ ] 🏃 If Invoke-Maester parameters are changed, update the GitHub action to use the new parameters.

</details>

## Next Steps

We will try to review your pull request as soon as possible. If you have any queries or need any help, please visit the [repository discussions](https://github.com/maester365/maester/discussions) or jump on [Discord](https://discord.maester.dev/). We really appreciate your contributions! 💖 Thank you!
<!-- While you wait for a review, why not spread some Maester love on social media? -->
