<#
.SYNOPSIS
    Send an adaptive card in a teams channel with the summary of the Maester test results

.DESCRIPTION
    Uses Graph API to send an adaptive card in a teams channel with the summary of the Maester test results.

    This command requires the ChannelMessage.Send delegate permission in the Microsoft Graph API.

    Note: Teamwork.Migrate.All application permission is required if running in a non-interactive environment (Azure DevOps, GitHub) to send messages to a channel.

    When running interactively this can be done by running the following command:

    ```
    Connect-MtGraph -SendTeamsMessage
    ```

    When running in a non-interactive environment (Azure DevOps, GitHub) the ChannelMessage.Send permission
    must be granted to the application in the Microsoft Entra portal.

.EXAMPLE
    Send-MtTeamsMessage -MaesterResults $MaesterResults -TeamId '00000000-0000-0000-0000-000000000000' -TeamChannelId '19%3A00000000000000000000000000000000%40thread.tacv2' -Subject 'Maester Results' -TestResultsUri "https://github.com/contoso/maester/runs/123456789"

    Sends an Adaptive Card in a Teams Channel with the summary of the Maester test results to the specified channel along with the link to the detailed test results.

.EXAMPLE
    Send-MtTeamsMessage -MaesterResults $MaesterResults -TeamChannelWebhookUri 'https://some-url.logic.azure.com/workflows/invoke?api-version=2016-06-01' -Subject 'Maester Results' -TestResultsUri "https://github.com/contoso/maester/runs/123456789"

    Sends an Adaptive Card in a Teams Channel with the summary of the Maester test results to the specified channel along with the link to the detailed test results.


.LINK
    https://maester.dev/docs/commands/Send-MtTeamsMessage
#>
function Send-MtTeamsMessage {
    [CmdletBinding()]
    param(
        # The Maester test results returned from `Invoke-Pester -PassThru | ConvertTo-MtMaesterResult`
        [Parameter(Mandatory = $true, Position = 0)]
        [psobject] $MaesterResults,

        # The Teams team where the test results should be posted.
        # To get the TeamId, right-click on the channel in Teams and select 'Get link to channel'. Use the value of groupId. e.g. ?groupId=<TeamId>
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = "MSGraph")]
        [string] $TeamId,

        # The channel where the message should be posted. e.g. 19%3A00000000000000000000000000000000%40thread.tacv2
        # To get the TeamChannelId, right-click on the channel in Teams and select 'Get link to channel'. Use the value found between channel and the channel name. e.g. /channel/<TeamChannelId>/my%20channel
        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = "MSGraph")]
        [string] $TeamChannelId,

        # The URL of the webhook where the message should be posted. e.g. 'https://some-url.logic.azure.com/workflows/invoke?api-version=2016-06-01'
        # To get the webhook Url, right-click on the channel in Teams and select 'Workflow'. Create a workflow using the 'Post to a channel when a webhook request is received' template. Use the value after complete
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = "Webhook")]
        [string] $TeamChannelWebhookUri,

        # The subject of the card. Defaults to 'Maester Test Results'.
        [string] $Subject,

        # Uri to the detailed test results page.
        [string] $TestResultsUri

    )

    <#
        # Developer guide for editing the Adaptive Card.
        - Authoring of the Adaptive Card is done using the Adaptive Card Designer.
        - Card Payload can be found in /powershell/assets/AdaptiveCardPayloadTemplate.json
        - Open https://adaptivecards.io/designer/, insert the payload and example data ($adaptiveCardData | ConvertTo-Json -depth 5)
        - Make changes as needed
        - Copy the payload and paste it into the /powershell/assets/AdaptiveCardPayloadTemplate.json file in the assets folder

        To do:
        - Add a switch to send the card to a user instead of a channel
    #>
    if (!$TeamChannelWebhookUri) {
      if (!(Test-MtContext -SendTeamsMessage)) { return }
    } else {
        # Check if TeamChannelWebhookUri is a valid URL
        $urlPattern = '^(https)://[^\s/$.?#].[^\s]*$'
        if (-not ($TeamChannelWebhookUri -match $urlPattern)) {
            Write-Output "Invalid Webhook URL: $TeamChannelWebhookUri"
            return
        }
    }

    if (!$Subject) { $Subject = "Maester Test Results" }

    $adaptiveCardTemplateFilePath = Join-Path -Path $PSScriptRoot -ChildPath '../assets/AdaptiveCardPayloadTemplate.json'
    $adaptiveCardTemplate = Get-Content -Path $adaptiveCardTemplateFilePath -Raw

    $CurrentVersion = $MaesterResults.CurrentVersion
    $LatestVersion = $MaesterResults.LatestVersion
    $ModuleVersion =
    if ($currentVersion -ne $latestVersion) {
        "$currentVersion → Latest version: $latestVersion"
    } else {
        "$currentVersion"
    }

    $NotRunCount = $MaesterResults.SkippedCount
    if ([string]::IsNullOrEmpty($MaesterResults.SkippedCount)) { $NotRunCount = "-" }

    $adaptiveCardData = @{
        title       = $Subject
        description = "Results for Maester Test run of $($MaesterResults.ExecutedAt)"
        run         = @{
            TenantName       = $MaesterResults.TenantName
            TenantId         = $MaesterResults.TenantId
            ModuleVersion    = $ModuleVersion
            TotalCount       = $MaesterResults.TotalCount
            PassedCount      = $MaesterResults.PassedCount
            FailedCount      = $MaesterResults.FailedCount
            InvestigateCount = $MaesterResults.InvestigateCount
            NotRunCount      = $NotRunCount
            TestResultURL    = $TestResultsUri
        }
    }

    # if $adaptiveCardData.run.TestResultURL is not set, remove the TestResultURL property from the adaptive card json template
    if (!$TestResultsUri) {
        $adaptiveCardData.run.Remove("TestResultURL")
        # Remove button with link to full testresults from the adaptive card json template
        $adaptiveCardTemplate = $adaptiveCardTemplate | ConvertFrom-Json
        $adaptiveCardTemplate.body = $adaptiveCardTemplate.body | Where-Object type -ne 'ActionSet'
        $adaptiveCardTemplate = $adaptiveCardTemplate | ConvertTo-Json -Depth 10
    }

    # Identify and replace variables because 'Inline Data' is not supported by Microsoft Teams...
    # This regex matches placeholders like ${$root.run.TestResultURL} and ${$root.TenantName}
    $pattern = '\$\{\$root\.([a-zA-Z0-9_.]+)\}'

    $adaptiveCardBody = [regex]::Replace($adaptiveCardTemplate, $pattern, {
            param($match)
            # Extract the property path from the match, splitting by '.'
            $propertyPath = $match.Groups[1].Value.Split('.')
            # Navigate through the $adaptiveCardData based on the property path
            $currentValue = $adaptiveCardData
            foreach ($property in $propertyPath) {
                if ($currentValue -is [System.Collections.IDictionary] -and $currentValue.ContainsKey($property)) {
                    $currentValue = $currentValue[$property]
                } else {
                    # Debugging output to help identify where it fails
                    Write-Verbose "Failed to find property: $property in path: $($match.Groups[1].Value)"
                    # If the property does not exist, return the original placeholder
                    return $match.Value
                }
            }
            # Return the final value to replace the placeholder
            $currentValue
        })

        # Set donut values
        $adaptiveCardBody = $adaptiveCardBody.replace('99990',$adaptiveCardData.run.PassedCount)
        $adaptiveCardBody = $adaptiveCardBody.replace('99991',$adaptiveCardData.run.FailedCount)

    if (!$TeamChannelWebhookUri)
    {
        $attachmentGuid = New-Guid

        $params = @{
            subject     = $null
            body        = @{
                contentType = "html"
                content     = "<attachment id=""$attachmentGuid""></attachment>"
            }
            attachments = @(
                @{
                    id           = "$attachmentGuid"
                    contentType  = "application/vnd.microsoft.card.adaptive"
                    contentUrl   = $null
                    content      = $adaptiveCardBody.toString()
                    name         = $null
                    thumbnailUrl = $null
                }
            )
        }

      Write-Verbose -Message "Uri: $SendTeamsMessageUri"

      $SendTeamsMessageUri = "https://graph.microsoft.com/v1.0/teams/$($TeamId)/channels/$($TeamChannelId)/messages"

      Invoke-MgGraphRequest -Method POST -Uri $SendTeamsMessageUri -Body $params | Out-Null
    }else
    {
        $params = @{
            type     = "message"
            attachments = @(
                @{
                    contentType  = "application/vnd.microsoft.card.adaptive"
                    contentUrl   = $null
                    content      = $null
                }
            )
        }

      $params.attachments[0].content = ($adaptiveCardBody | convertFrom-Json)
      Write-Verbose -Message "Posting message to Teams channel using webhook: $TeamChannelWebhookUri"
      Invoke-RestMethod -Method post -ContentType 'Application/Json' -Body ($params | ConvertTo-Json -Depth 25) -Uri $TeamChannelWebhookUri
    }
}