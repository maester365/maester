---
title: Your first custom test
sidebar_position: 0
description: A step-by-step start for IT admins who want Maester to check one of their own rules. No Maester internals needed.
---

# Your first custom test

Maester ships with hundreds of tests. This page is for when you want it to check a rule of your own, such as
"guests cannot invite other guests" or "every disabled policy says why it is disabled". You need to know a
little PowerShell. You do not need to know how Maester works inside.

You will write one small PowerShell function. It reads a setting from your tenant and answers yes or no. Maester
does the rest: it connects, runs the function, catches errors and puts the result in the report next to the
built-in tests.

## Before you start

- Maester is installed and you can run `Connect-Maester`. See the [installation guide](../installation.md).
- You have a folder for your own tests, for example `~/maester`. Any empty folder works. Your tests go in a `custom`
  folder inside it, which `New-MtTest` creates, and updating Maester never touches it.

## Step 1: Create the test

Open PowerShell in your Maester folder and run:

```powershell
New-MtTest -Id CT.1001 -Title 'Only admins and guest inviters can invite guests'
```

This writes two files into `custom`:

| File | What it is for |
| --- | --- |
| `Test.CT.1001.ps1` | The check: one PowerShell function. |
| `Test.CT.1001.md` | The text shown in the report: what is checked and how to fix it. |

`CT.1001` is the test's ID. Pick a prefix of your own, such as `CT` or your company name, and a number. Do not
use `MT`, `CIS`, `CISA`, `EIDSCA`, `ORCA`, `AD` or `AZDO`: those belong to the tests that ship with Maester.

:::tip
Prefer forms to typing? The [test builder](pathname:///test-builder) lets you pick everything from lists. Choose
**My own custom test**, and copy the code it writes.
:::

## Step 2: Write the check

Open `custom/Test.CT.1001.ps1` and replace its contents with this:

```powershell
function Test-CT1001 {
    [MaesterTest(
        Id       = 'CT.1001',
        Title    = 'Only admins and guest inviters can invite guests',
        Severity = 'Medium',
        Service  = 'Graph'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # 1. Read the setting from the tenant.
    $policy = Invoke-MtGraphRequest -RelativeUri 'policies/authorizationPolicy'

    # 2. Decide.
    $passed = $policy.allowInvitesFrom -in 'adminsAndGuestInviters', 'none'

    # 3. Say what you found, then answer yes or no.
    if ($passed) {
        Add-MtTestResultDetail -Result 'Well done. Guest invitations are restricted.'
    } else {
        Add-MtTestResultDetail -Result "Guest invitations are open to: **$($policy.allowInvitesFrom)**."
    }
    return $passed
}
```

What each part does:

- **`[MaesterTest(...)]`** tells Maester about the test. Only `Id` and `Title` are required. `Severity` sets how
  the result is ranked in the report. `Service = 'Graph'` says the test needs Microsoft Graph, so Maester skips it,
  instead of failing it, when you are not connected.
- **`Invoke-MtGraphRequest`** reads from Microsoft Graph with the connection `Connect-Maester` made. Use
  [Graph Explorer](https://aka.ms/ge) to find the address and the property you need.
- **`Add-MtTestResultDetail -Result`** is the sentence people see in the report. Write it so someone who did not
  write the test knows what is wrong.
- **`return $true`** means passed, and **`return $false`** means failed. Return exactly one of them.

You do not need `try`/`catch`, a connection check or a licence check. If the function throws, Maester reports the
test as an error and keeps going.

## Step 3: Write what the report shows

Open `custom/Test.CT.1001.md` and replace its contents:

```md
Checks that only administrators and users with the Guest Inviter role can invite guests.

When any member or guest can invite people, accounts from outside the company appear in your directory without
anyone reviewing them.

#### Remediation action

1. Open the [External collaboration settings](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/CompanyRelationshipsMenuBlade/~/Settings) in the Microsoft Entra admin center.
2. Under **Guest invite settings**, choose **Only users assigned to specific admin roles can invite guest users**.
3. Select **Save**.

<!--- Results --->
%TestResult%
```

Keep the last two lines as they are. `%TestResult%` is where the sentence from step 2 appears.

## Step 4: Check it and run it

```powershell
# Check the files are valid. This does not need a connection.
Get-MtTest -Path ./custom

# Connect, then run only your test.
Connect-Maester
Invoke-MtTest -Path ./custom/Test.CT.1001.ps1
```

`Get-MtTest` should list your test with no errors. `Invoke-MtTest` prints the result: `Passed`, `Failed`,
`Skipped` or `Error`, with your sentence.

## Step 5: Run it with everything else

```powershell
Invoke-Maester                  # the built-in tests plus your custom tests
Invoke-Maester -SkipBuiltIn     # only your custom tests
```

Your test now appears in the HTML report with the others.

## If something goes wrong

| You see | What it means | Fix |
| --- | --- | --- |
| `Error` with `InvalidMetadata` | Maester could not read the test. | Check the file is named `Test.<ID>.ps1`, the `Id` matches the name, and the `.md` file is beside it. |
| `Error` with `InvalidReturn` | The function returned something other than one `$true` or `$false`. | Look for a line whose output you did not store in a variable; put `$null =` in front of it. |
| `Skipped` | A service the test needs is not connected. | Run `Connect-Maester` with the service the test names. |
| `Error` with `TestError` | The function threw. | Read the message in the result; it is usually a wrong Graph address or a missing permission. |
| A warning about the prefix | The ID starts with a prefix Maester uses. | Rename the test to your own prefix. |

## Where to go next

- **Show a table of the objects that failed**, with links to the admin portal: [Formatting test results](./formatting-test-results.md).
- **Skip the test in tenants without a licence**, add settings people can change, or produce one result per
  object: [Writing native tests](./index.mdx).
- **Map the test to CIS, CISA or NIST**, or give it a product and area so it can be filtered:
  the [test builder](pathname:///test-builder) explains each choice.
- **Already have tests written for Maester 2.x with Pester?** They still run. See
  [Pester-format tests](./pester-format-tests.md).
