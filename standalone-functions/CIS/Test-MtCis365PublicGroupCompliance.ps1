function Test-MtCis365PublicGroupCompliance {
    <#
    .SYNOPSIS
    Checks if there are public groups

    .DESCRIPTION
    Ensure that only organizationally managed and approved public groups exist
    CIS Microsoft 365 Foundations Benchmark v6.0.1
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCis365PublicGroupCompliance
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
        $graphContext = Get-MgContext
        if ($null -eq $graphContext) {
            Write-Verbose "Not connected to Microsoft Graph"
            return $null
        }
    } catch {
        Write-Verbose "Microsoft Graph connection check failed: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation

    try {
        Write-Verbose 'Getting all Microsoft 365 Groups'
        $365GroupList = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/groups'.0

        Write-Verbose 'Filtering out private 365 groups'
        $result = $365GroupList | Where-Object { $_.visibility -eq 'Public' }

        $testResult = ($result | Measure-Object).Count -eq 0
        foreach ($item in $result) {
            # We are restricting the table output to 50 below as it could be extremely large
        }
        # Add a limited results message if more than 6 results are returned


        return $testResult
    } catch {
        return $null
    }

}
