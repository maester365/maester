function Test-MtCisaExternalSenderWarningCompliance {
    <#
    .SYNOPSIS
    Checks state of transport policies

    .DESCRIPTION
    External sender warnings SHALL be implemented.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisaExternalSenderWarningCompliance
    if ($result -eq $true) { Write-Host "Compliant" }
    elseif ($result -eq $false) { Write-Host "Non-Compliant" }
    else { Write-Host "Skipped or Error" }

    .OUTPUTS
    bool|null - Returns true if compliant, false if non-compliant, null if skipped or error
    #>
    [CmdletBinding()]
    [OutputType([bool], [nullable])]
    param()

    # Phase 1: Prerequisites Check
    try {
        $exoSession = Get-PSSession | Where-Object { $_.ConfigurationName -eq 'Microsoft.Exchange' -and $_.State -eq 'Opened' }
        if ($null -eq $exoSession) {
            Write-Verbose "Not connected to Exchange Online"
            return $null
        }
    } catch {
        Write-Verbose "Exchange Online connection check failed: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation

    $ExternalSenderIdentification = Get-ExternalInOutlook

    if ($ExternalSenderIdentification.Enabled -eq $true) {
        $testResult = $true
    } else {

        $rules = Get-TransportRule

        $resultRules = $rules | Where-Object {`
                $_.State -eq "Enabled" -and `
                $_.Mode -eq "Enforce" -and `
                $_.FromScope -eq "NotInOrganization" -and `
                $_.SenderAddressLocation -eq "Header" -and `
                $_.PrependSubject -like "*[External]*"
        }

        $testResult = ($resultRules | Measure-Object).Count -ge 1
    }
    if ($rules) {
        # Only show table if there are rules
        $result = "| Transport Rule Name | Test Result |`n"
        $result += "| --- | --- |`n"
    }

    if ( $ExternalSenderIdentification.Enabled -eq $true ) {
        $result = "Exchange External Sender Identification is enabled.`n`n"
        if ( -not [string]::IsNullOrWhiteSpace($ExternalSenderIdentification.AllowList) ) {
            $result += "The following domains are allowed to bypass the external sender warning:`n"
            foreach ( $item in $ExternalSenderIdentification.AllowList ) {
                $result += " * $item`n"
            }
        } else {
            $result += "No domains are allowed to bypass the external sender warning.`n"

        }
    }


    return $testResult

}
