---
sidebar_label: Slack Alerts
sidebar_position: 10
title: Set up Maester Slack alerts
---

# Set up Maester Slack Alerts

Your Maester monitoring workflow can be configured to send a summary at the end of each monitoring cycle in Slack. This guide will walk you through the steps to set up Slack alerts in Maester.

## Prerequisites

### Create a Slack App and Incoming Webhook
- Open the [Your apps](https://api.slack.com/apps) in the Slack API portal
- Click on "**Create New App**"
- Enter a name for your app, for example `Maester DevOps` and select the Slack workspace where you want to post the notifications.
- Click "**Create App**".

## Enable Incoming Webhooks:
- In your Slack app settings, go to **Incoming Webhooks**.
- Click on **Activate Incoming Webhooks** to enable it.
- Click **Add New Webhook to Workspace** at the bottom.
- Select the channel where you want to post the messages and click **Allow**.
- Copy the webhook URL provided. You will need this URL in the GitHub Actions workflow.

## Add Secret to GitHub Repository:
- Go to your GitHub repository.
- Click on **Settings** > **Secrets and variables** > **Actions**.
- Click "**New repository secret**".
- Name the secret `SLACK_WEBHOOK_URL`.
- Paste the Slack webhook URL you copied earlier and click **Add secret**.

## Add the Slack alert step to your workflow
Update your GitHub daily monitoring workflow to send the Slack alert using the webhook with the following code:

```powershell

    - name: Generate Slack Notification
      shell: pwsh
      run: |
        $results = Get-Content test-results/test-results.json | ConvertFrom-Json

        $testSummary = "Test Summary:`n-------------`nPassed: $($results.PassedCount)`nFailed: $($results.FailedCount)`nSkipped: $($results.SkippedCount)`nTotal: $($results.TotalCount)"

        $runLink = "${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"

        $slackMessage = @{
          text = "Maester Test Results"
          attachments = @(
            @{
              color = if ($results.Result -eq 'Passed') { "good" } else { "danger" }
              text = $testSummary
            },
            @{
              title = "Detailed Report"
              title_link = $runLink
              text = "Click the link above to view the full report."
            }
          )
        }

        Invoke-RestMethod -Uri "${{ secrets.SLACK_WEBHOOK_URL }}" -Method Post -ContentType 'application/json' -Body ($slackMessage | ConvertTo-Json -Depth 4)

    - name: Notify Slack on success
      if: success()
      run: |
        curl -X POST -H 'Content-type: application/json' --data '{"text":"Maester tests passed!"}' "${{ secrets.SLACK_WEBHOOK_URL }}"

    - name: Notify Slack on failure
      if: failure()
      run: |
        curl -X POST -H 'Content-type: application/json' --data '{"text":"Maester tests failed!"}' "${{ secrets.SLACK_WEBHOOK_URL }}"
```

## Important Notes:
- Webhook URL: Ensure you have the `SLACK_WEBHOOK_URL` secret set up in your GitHub repository.
- GitHub Link: The link to the GitHub Actions run is dynamically generated using `${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}`

## Customize the App Icon (Optional)
- Open App Settings
- In the left sidebar, click on **Basic Information**.
- Scroll down to the **Display Information** section.
- Here, you will find an option to upload an app icon. The recommended size is 512x512 pixels.
- Click **Edit** next to the **App Icon** section.
- Upload your custom icon image.
- After uploading the image, make sure to save your changes.
