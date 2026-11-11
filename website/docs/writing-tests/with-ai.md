---
title: Write a test with AI
description: Use an AI coding assistant to write a Maester test, for your own tenant or as a contribution. What to give it, the prompt to use, and how to check what it writes.
sidebar:
  order: 1.5
---

# Write a test with AI

An AI coding assistant such as [GitHub Copilot](https://docs.github.com/copilot) or
[Claude Code](https://docs.claude.com/en/docs/claude-code) can write a Maester test for you: the `Test.<ID>.ps1`
file with its `[MaesterTest()]` attribute and the `Test.<ID>.md` file the report shows. This works for a custom
test that stays in your own folder and for a test you want to contribute to Maester.

You bring two things the assistant cannot work out: **what the test should verify**, and a tenant to run it on.
The assistant brings the PowerShell, the attribute and the remediation text.

## The short version

1. Open the [test builder](/test-builder) and choose who the test is for.
2. Fill in what you know. The ID and the title are enough; every value you pick is one less for the assistant
   to guess.
3. Open **Write it with AI**, below the steps, say in a sentence or two what the test should verify, and copy
   the prompt.
4. Paste it into your assistant, in the right folder (see below).
5. Review what it wrote, then run the test on a tenant you know.

## What to tell the assistant

A good description names the setting, the value you expect and the reason:

> Guest users cannot invite other guests. The setting is "Guest invite restrictions" under External
> collaboration settings in the Entra admin center. It should be "Only users assigned to specific admin roles",
> because an open setting lets any guest bring more outsiders into the tenant.

If you know them, add where the setting is read from (a Microsoft Graph endpoint, an Exchange cmdlet), the
licence the feature needs, and any exceptions your organization allows. Say when you do not know: the assistant
should look the endpoint up, not make one up.

## A custom test

A custom test lives in your own folder, such as `./custom`, and never leaves your organization. The assistant
does not need the Maester repository. The prompt from the test builder points it at the published guides, which
are also served as plain Markdown for this purpose:

- [Your first custom test](./first-custom-test.md): `https://maester.dev/docs/writing-tests/first-custom-test.md`
- [Writing native tests](./index.mdx): `https://maester.dev/docs/writing-tests.md`
- [Formatting test results](./formatting-test-results.md): `https://maester.dev/docs/writing-tests/formatting-test-results.md`

Run the assistant in the folder that holds your custom tests, on a computer with the Maester module installed,
so it can check its own work:

```powershell
Get-MtTest -Path ./custom                        # reads the files and reports mistakes; needs no tenant
Invoke-MtTest -Path ./custom/Test.CT.1001.ps1    # runs the one test against the connected tenant
```

A chat assistant that cannot run commands works too. Ask it for both files in full, save them yourself and run
the two commands.

If you would rather write the prompt yourself, this is the shape of it:

```text
Write a custom Maester test for me. Maester (https://maester.dev) is a PowerShell framework that checks the
security configuration of Microsoft 365.

What the test should verify:
<the setting, the value you expect and why>

Read these guides first:
- https://maester.dev/docs/writing-tests/first-custom-test.md
- https://maester.dev/docs/writing-tests.md
- https://maester.dev/docs/writing-tests/formatting-test-results.md

Create ./custom/Test.CT.1001.ps1 and ./custom/Test.CT.1001.md. Use only commands the Maester module exports.
Declare Service and License in the attribute instead of checking connections or licences in code, use no outer
try/catch, and return $true or $false. Check the files with Get-MtTest -Path ./custom.

Do not invent Graph endpoints or property names: say so when you are not sure one exists.
```

## A test for Maester

A test you contribute has more rules: every attribute of the [rubric](./attribute-rubric.md) is required, the
check must not duplicate one another suite already has, and the unit tests enforce naming and layout. The
repository carries that knowledge for the assistant, so work in a clone of
[maester365/maester](https://github.com/maester365/maester):

- `AGENTS.md` holds the rules every agent follows.
- The `maester-test-expert` skill is the full guide to writing a check, and the `maester-test-planner` agent
  plans one before any code is written. [Agents and skills](../agents-and-skills.md) lists them all.

GitHub Copilot and Claude Code load these when you open the repository. The prompt from the test builder names
them as well, for an assistant that does not, and asks it to:

1. Look for an existing test of the same setting, and stop if there is one.
2. Create the two files from the values you picked, and say which attribute values it would change.
3. Write the check and the remediation text.
4. Validate with `Get-MtTest`, regenerate the golden fixture, and run `./powershell/tests/pester.ps1`.
5. Leave the commit and the pull request to you.

Reserve the test's `MT.` number on [issue 697](https://github.com/maester365/maester/issues/697) before you open
the pull request. The [contributing guide](../contributing.md) covers the rest.

## Check what it wrote

An assistant writes confident code whether or not it is right. Before you rely on a test:

- **Check the data source.** Open the Microsoft Learn page for the Graph endpoint or cmdlet and confirm the
  property names and the values they can have. A made-up property reads as empty, and the test then passes or
  fails for the wrong reason.
- **Run it both ways.** Run the test on a tenant where you know the answer. If you can, change the setting in a
  test tenant and confirm the result flips.
- **Read the result as a user would.** The failure message should name what is wrong and the `.md` should give
  steps someone can follow, with a link that opens the right portal page.
- **Check the permissions.** The test should ask for the least privileged permission that reads the data.
- **Review the ratings.** For a contribution, compare `Severity`, `UserImpact` and `ImplementationCost` with the
  [rubric](./attribute-rubric.md). A reviewer will.

You are the author of a test you submit, whoever typed it. Put your own GitHub handle in `Author`.
