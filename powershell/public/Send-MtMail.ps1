function Send-MtMail {
    <#
    .SYNOPSIS
    Send an email with the summary of the Maester test results

    .DESCRIPTION
    Uses Graph API to send an email with the summary of the Maester test results.

    This command requires the Mail.Send permission in the Microsoft Graph API.

    When running interactively this can be done by running the following command:

    ```
    Connect-MtGraph -SendMail
    ```

    When running in a non-interactive environment (Azure DevOps, GitHub) the app needs permission to send from a mailbox,
    see https://maester.dev/docs/monitoring/email/ for instructions.

    .EXAMPLE
    Send-MtMail -MaesterResults $MaesterResults -Recipient john@contoso.com, sam@contoso.com -Subject 'Maester Results' -TestResultsUri "https://github.com/contoso/maester/runs/123456789"

    Sends an email with the summary of the Maester test results to two users along with the link to the detailed test results.

    .LINK
    https://maester.dev/docs/commands/Send-MtMail
    #>
    [OutputType([System.Collections.Hashtable])]
    [CmdletBinding()]
    param(
        # The Maester test results returned from `Invoke-Pester -PassThru | ConvertTo-MtMaesterResult`
        [Parameter(Mandatory = $true, Position = 0)]
        [psobject] $MaesterResults,

        # The email addresses of the recipients. e.g. john@contoso.com
        [Parameter(Mandatory = $true, Position = 1)]
        [string[]] $Recipient,

        # The subject of the email. Defaults to 'Maester Test Results'.
        [string] $Subject,

        # Absolute HTTP or HTTPS URI to the detailed test results page.
        [string] $TestResultsUri,

        # Does not send the email, but outputs the body to use elsewhere
        [switch] $CreateBodyOnly,

        # The user id of the sender of the mail. Defaults to the current user.
        # This is required when using application permissions.
        # Accepts either a GUID or UPN (User Principal Name) format.
        [ValidateScript({
                if ($_ -and $_ -notmatch '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$' -and $_ -notmatch '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$') {
                    throw "Invalid UserId format. It should be a valid GUID or UPN (User Principal Name)."
                }
                return $true
            })]
        [ValidateNotNullOrEmpty()]
        [string] $UserId
    )

    <#
        # Developer guide for editing the html report.
        - Authoring of the email template is done using Word. Open /powershell/assets/EmailTemplate.docx and make changes as needed
        - Select all and copy/paste the content into a new email in Outlook and send it to yourself
        - When the email is received, view the source (either through Graph API, View Source in Outlook for Mac or save as .eml and open in a text editor)
        - Copy the source (<html>..</html>) and paste it into the /powershell/assets/EmailTemplate.html file in the assets folder
        - Search for cid:image in the html and update the -replace commands in the script below.
    #>
    if (! ($CreateBodyOnly)) {
        if (!(Test-MtContext -SendMail)) { return }
        if ($context.AuthType -ne 'Delegated' -and -not $PSBoundParameters.ContainsKey('UserId')) {
            throw "When running as an application, the UserId parameter must be specified."
        }

        if (!$Subject) { $Subject = "Maester Test Results" }
    }

    $emailTemplateFilePath = Join-Path -Path $PSScriptRoot -ChildPath '../assets/EmailTemplate.html'
    $emailTemplate = Get-Content -Path $emailTemplateFilePath -Raw

    $imgMaesterLogo = "https://maester.dev/img/logo.svg"
    $imgPassedIcon = "https://maester.dev/img/test-result/icon-pass.png"
    $imgFailedIcon = "https://maester.dev/img/test-result/icon-fail.png"
    $imgNotRunIcon = "https://maester.dev/img/test-result/icon-notrun.png"

    $emailTemplate = $emailTemplate -replace "cid:image001.png@01DAC7D0.5D7D03D0", $imgMaesterLogo
    $emailTemplate = $emailTemplate -replace "cid:image002.png@01DAC7D0.5D7D03D0", $imgMaesterLogo
    $emailTemplate = $emailTemplate -replace "cid:image003.png@01DAC7D0.5D7D03D0", $imgPassedIcon
    $emailTemplate = $emailTemplate -replace "cid:image004.png@01DAC7D0.5D7D03D0", $imgFailedIcon
    $emailTemplate = $emailTemplate -replace "cid:image005.png@01DAC7D0.5D7D03D0", $imgNotRunIcon

    $CurrentVersion = $MaesterResults.CurrentVersion
    $LatestVersion = $MaesterResults.LatestVersion
    $ModuleVersion =
    if ($currentVersion -ne $latestVersion) {
        "$currentVersion → Latest version: $latestVersion"
    } else {
        "$currentVersion"
    }

    $notRunCount = $MaesterResults.NotRunCount
    if ([string]::IsNullOrEmpty($MaesterResults.NotRunCount)) { $notRunCount = "-" }
    $skippedCount = $MaesterResults.SkippedCount
    if ([string]::IsNullOrEmpty($MaesterResults.SkippedCount)) { $skippedCount = "-" }
    $investigateCount = $MaesterResults.investigateCount
    if ([string]::IsNullOrEmpty($MaesterResults.investigateCount)) { $investigateCount = "-" }

    # Encode result values for HTML text, including the message preview.
    $templateValues = @{
        TenantName       = [System.Net.WebUtility]::HtmlEncode([string]$MaesterResults.TenantName)
        TenantId         = [System.Net.WebUtility]::HtmlEncode([string]$MaesterResults.TenantId)
        ModuleVersion    = [System.Net.WebUtility]::HtmlEncode([string]$ModuleVersion)
        TotalCount       = [System.Net.WebUtility]::HtmlEncode([string]$MaesterResults.TotalCount)
        PassedCount      = [System.Net.WebUtility]::HtmlEncode([string]$MaesterResults.PassedCount)
        FailedCount      = [System.Net.WebUtility]::HtmlEncode([string]$MaesterResults.FailedCount)
        InvestigateCount = [System.Net.WebUtility]::HtmlEncode([string]$investigateCount)
        SkippedCount     = [System.Net.WebUtility]::HtmlEncode([string]$skippedCount)
        NotRunCount      = [System.Net.WebUtility]::HtmlEncode([string]$notRunCount)
    }

    # Add a hidden div that will show in the preview line of the message.
    $bodyElement = [regex]::Match($emailTemplate, '<body\b[^>]*>', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase).Value
    if ($bodyElement) {
        $emailTemplate = $emailTemplate.Replace($bodyElement,($bodyElement + "<div style='display:none;'>🔥 Total: %TotalCount%, ✅ Passed: %PassedCount%, ❌ Failed: %FailedCount%, 🔍 Investigate: %InvestigateCount%, ⏭️ Skipped: %SkippedCount%, ⬇️ Not Run: %NotRunCount%</div>"))
    }
    $StatusIcon = @{
        Passed      = '<img src="https://maester.dev/img/test-result/pill-pass.png" height="25" alt="Passed"/>'
        Failed      = '<img src="https://maester.dev/img/test-result/pill-fail.png" height="25" alt="Failed"/>'
        Skipped     = '<img src="https://maester.dev/img/test-result/pill-notrun.png" height="25" alt="Skipped"/>'
        NotRun      = '<img src="https://maester.dev/img/test-result/pill-notrun.png" height="25" alt="Not Run"/>'
        Investigate = '<img src="https://maester.dev/img/test-result/pill-investigate.png" height="25" alt="Investigate"/>'
    }

    $table = "<table border='1' cellpadding='10' cellspacing='2' style='border-collapse: collapse; border-color: #f6f8fa;'><tr><th>Test Name</th><th>Status</th></tr>"
    $counter = 0
    foreach ($test in $MaesterResults.Tests) {
        $rowColor = ""
        if ($counter % 2 -eq 0) { $rowColor = "style='background-color: #f6f8fa'" }
        $testName = [System.Net.WebUtility]::HtmlEncode([string]$test.Name)
        $testResult = [System.Net.WebUtility]::HtmlEncode([string]$test.Result)
        $table += "<tr $rowColor><td>$testName</td><td style='text-align: center; vertical-align: middle;'>$($StatusIcon[$test.Result]) $testResult</td></tr>"
        $counter++
    }
    $table += "</table>"

    $templateValues.TestSummary = $table

    $testResultsLink = ""
    if ($TestResultsUri) {
        $resultsUri = $null
        if ([Uri]::TryCreate($TestResultsUri, [UriKind]::Absolute, [ref]$resultsUri) -and
            $resultsUri.Scheme -in @('http', 'https')) {
            $encodedUri = [System.Net.WebUtility]::HtmlEncode($resultsUri.AbsoluteUri)
            $testResultsLink = "<a href='$encodedUri'>View detailed test results</a>"
        } else {
            # Don't fail the whole run (e.g. at the end of Invoke-Maester) over a bad link; send without it.
            Write-Warning 'TestResultsUri must be an absolute HTTP or HTTPS URI. The link to the detailed test results was omitted from the email.'
        }
    }
    $templateValues.TestResultsLink = $testResultsLink

    # Replace placeholders once, preserving literal dollar signs and placeholder-like result text.
    $emailTemplate = [regex]::Replace($emailTemplate, '%(TenantName|TenantId|ModuleVersion|TotalCount|PassedCount|FailedCount|InvestigateCount|SkippedCount|NotRunCount|TestSummary|TestResultsLink)%', {
        param($match)
        $templateValues[$match.Groups[1].Value]
    }, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    $mailRequestBody = @{
        message         = @{
            subject      = "$Subject"
            body         = @{
                contentType = "HTML"
                content     = "$emailTemplate"
            }
            toRecipients = @()
        }
        saveToSentItems = "false"
    }

    foreach ($email in $Recipient) {
        $mailRequestBody.message.toRecipients += @{
            emailAddress = @{
                address = $email
            }
        }
    }

    $sendMailUri = '/v1.0/me/sendMail'

    if ($UserId) {
        $sendMailUri = "/v1.0/users/$UserId/sendMail"
    }

    Write-Verbose -Message "Uri: $sendMailUri"
    # Construct the message body
    if ($CreateBodyOnly) {
        return $mailRequestBody
    }

    # Send email
    try {
        Invoke-MgGraphRequest -Method POST -Uri $sendMailUri -Body $mailRequestBody
    } catch {
        if ($_.Exception.Response.StatusCode -eq 403) {
            # Delegated Mail.Send permission is checked earlier, so this is likely an application permission issue
            Write-Error -Message "Sending email failed with access denied. Make sure you've granted Mail.Send permission to the specified mailbox, see https://maester.dev/docs/monitoring/email/ for instructions."
        }
        throw
    }
}
