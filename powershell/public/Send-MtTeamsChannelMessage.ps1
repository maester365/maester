<#
.SYNOPSIS
    Send an adaptive card in a teams channel with the summary of the Maester test results

.DESCRIPTION
    Uses Graph API to send an adaptive card in a teams channel with the summary of the Maester test results.

    This command requires the ChannelMessage.Send permission in the Microsoft Graph API.

    When running interactively this can be done by running the following command:

    ```
    Connect-MtGraph -SendChannelMessage
    ```

    When running in a non-interactive environment (Azure DevOps, GitHub) the ChannelMessage.Send permission
    must be granted to the application in the Microsoft Entra portal.

.EXAMPLE
    Send-MtTeamsChannelMessage -MaesterResults $MaesterResults -TeamId <guid> -ChannelId <guid> -Subject 'Maester Results' -TestResultsUri "https://github.com/contoso/maester/runs/123456789"

    Sends an Adaptive Card in a Teams Channel with the summary of the Maester test results to the specified channel along with the link to the detailed test results.
#>

Function Send-MtTeamsChannelMessage {
    [CmdletBinding()]
    param(
        # The Maester test results returned from `Invoke-Pester -PassThru | ConvertTo-MtMaesterResult`
        [Parameter(Mandatory = $true, Position = 0)]
        [psobject] $MaesterResults,

        # The team id of where the message should be posted. e.g. 5ba5cbbb-675e-4a8d-a382-a52960a18b4d
        [Parameter(Mandatory = $true, Position = 1)]
        [string[]] $TeamId,

        # The channel id of where the message should be posted. e.g. 19:4a95f7d8db4c4e7fae857bcebe0623e6@thread.tacv2
        [Parameter(Mandatory = $true, Position = 2)]
        [string[]] $ChannelId,

        # The subject of the card. Defaults to 'Maester Test Results'.
        [string] $Subject,

        # Uri to the detailed test results page.
        [string] $TestResultsUri

    )

    <#
        # Developer guide for editing the Adaptive Card.
        - Authoring of the Adaptive Card is done using the Adaptive Card Designer.
        - Card Payload can be found in /powershell/assets/AdaptiveCard.json
        - Open https://adaptivecards.io/designer/, insert the payload and example data ($adaptiveCardData | ConvertTo-Json -depth 5)
        - Make changes as needed
        - Copy the payload and paste it into the /powershell/assets/AdaptiveCardPayloadTemplate.json file in the assets folder

        To do:
        - Add a switch to send the card to a user instead of a channel
    #>
    if (!(Test-MtContext -SendChannelMessage)) { return }

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

    $notRunCount = $MaesterResults.SkippedCount
    if ([string]::IsNullOrEmpty($MaesterResults.SkippedCount)) { $notRunCount = "-" }

    $adaptiveCardData = @{
            title       = $Subject
            description = "Results for Maester Test run of $($MaesterResults.ExecutedAt)"
            run         = @{
                tenantName    = $MaesterResults.TenantName
                tenantId      = $MaesterResults.TenantId
                moduleVersion = $ModuleVersion
                TotalCount    = $MaesterResults.TotalCount
                PassedCount   = $MaesterResults.PassedCount
                FailedCount   = $MaesterResults.FailedCount
                NotRunCount   = $notRunCount
                TestResultURL = $TestResultsUri
            }

    }

    # if $adaptiveCardData.run.TestResultURL is not set, remove the TestResultURL property from the adaptive card json template
    if(!$TestResultsUri){
        $adaptiveCardData.run.Remove("TestResultURL")
        # Remove button with link to full testresults from the adaptive card json template
        $adaptiveCardTemplate = $adaptiveCardTemplate | ConvertFrom-Json
        $adaptiveCardTemplate.body = $adaptiveCardTemplate.body | Where-Object type -ne 'ActionSet'
        $adaptiveCardTemplate = $adaptiveCardTemplate | ConvertTo-Json -Depth 10
    }

    # Identify and replace variables because 'Inline Data' is not supported by Microsoft Teams...
    # This regex matches placeholders like ${$root.run.TestResultURL}
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
                Write-Host "Failed to find property: $property in path: $($match.Groups[1].Value)"
                # If the property does not exist, return the original placeholder
                return $match.Value
            }
        }
        # Return the final value to replace the placeholder
        $currentValue
    })

    $attachmentGuid = New-Guid

    $params = @{
        subject = $null
        body    = @{
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

    Write-Verbose -Message "Uri: $sendChannelMessageUri"

    $sendChannelMessageUri = "https://graph.microsoft.com/v1.0/teams/$($TeamId)/channels/$($ChannelId)/messages"

    Invoke-MgGraphRequest -Method POST -Uri $sendChannelMessageUri -Body $params | Out-Null

}