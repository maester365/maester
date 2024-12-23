---
sidebar_label: Email Alerts
sidebar_position: 8
title: Set up Maester email alerts
---

# Set up Maester Email Alerts

Your Maester monitoring workflow can be configured to send an email summary at the end of each monitoring cycle. This guide will walk you through the steps to set up email alerts in Maester.

![Email Alerts](assets/email-alert-test-results.png)

## Prerequisites

### Mail.Send graph permissions

The app that sends the email alerts needs the `Mail.Send` permission to send emails. To configure

- Open the [Entra admin center](https://entra.microsoft.com) > **Identity** > **Applications** > **App registrations**
- Search for the application you created to run as the `Maester DevOps Account`.
- Select **API permissions** > **Add a permission**
- Select **Microsoft Graph** > **Application permissions**
- Search for `Mail.Send` and check the box next to the permission
- Select **Add permissions**
- Select **Grant admin consent for [your organization]**
- Select **Yes** to confirm

:::info Important
It is recommended to limit the scope of the `Mail.Send` permission to only the mailbox that will be used to send the email alerts.

This can be done by configuring an Application Access Policy in Exchange Online. For more information, see [Limiting application permissions to specific Exchange Online mailboxes](https://learn.microsoft.com/graph/auth-limit-mailbox-access).
:::

## Add the email alert step to your workflow

Update your GitHub/Azure DevOps daily monitoring workflow to send the email alert using `Send-MtMail` after the Maester tests have been run.

**Note:** A UserId is required when running under an application context. This can be the UserId of any user or mailbox account in the tenant and will be the mailbox from where this message is sent from.

```powershell
# Get the results of the Maester tests using -PassThru
$results = Invoke-Maester -Path tests/Maester/ {...} -PassThru

# Send the email summary using the results
Send-MtMail $results -Recipient john@contoso.com -UserId <guid>
```

## Adding a link to detailed Maester results in the email

The Send-MtMail cmdlet has a `-TestResultsUri` parameter that can be used to include a link to the detailed Maester results in the email.

To use this parameter, you need to provide the URL of the Maester results page. Use the appropriate url format based on the CI/CD system you are using.

### GitHub

**Link:** `${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}`

```powershell
$testResultsUri = "${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"
Send-MtMail $results -Recipient $recipients -UserId $userId -TestResultsUri $testResultsUri
```

### Azure DevOps
**Link:** `$(System.CollectionUri)$(System.TeamProject)/_build/results?buildId=$(Build.BuildId)`

```powershell
$testResultsUri = "$(System.CollectionUri)$(System.TeamProject)/_build/results?buildId=$(Build.BuildId)"
Send-MtMail $results -Recipient $recipients -UserId $userId -TestResultsUri $testResultsUri
```
