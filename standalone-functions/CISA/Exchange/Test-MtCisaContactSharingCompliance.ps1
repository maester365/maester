function Test-MtCisaContactSharingCompliance {
    <#
    .SYNOPSIS
    Checks state of sharing policies

    .DESCRIPTION
    Contact folders SHALL NOT be shared with all domains.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisaContactSharingCompliance
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

    $policies = Get-SharingPolicy

    $resultPolicies = $policies | Where-Object {`
        $_.Enabled -and `
        ($_.Domains -like "`*:*ContactsSharing*" -or `
         $_.Domains -like "Anonymous:*ContactsSharing*")
    }

    $testResult = ($resultPolicies|Measure-Object).Count -eq 0
    $result = "| Policy Name | Test Result |`n"
    $result += "| --- | --- |`n"
    return $testResult

}
