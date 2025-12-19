<#
.SYNOPSIS
    Checks AD Domain FSMO Status

.DESCRIPTION
    Identifies if FSMO roles are on a single DC

.PARAMETER Server
    Server name to pass through to the AD Cmdlets

.PARAMETER Credential
    Credential object to pass through to the AD Cmdlets

.EXAMPLE
    Test-MtAdDomainFsmoStatus

    Returns true if AD domain FSMO roles are on single DC

.LINK
    https://maester.dev/docs/commands/Test-MtAdDomainFsmoStatus
#>
function Test-MtAdDomainFsmoStatus {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Proper name')]
    [OutputType([bool])]
    param(
        [string]$Server = $__MtSession.AdServer,
        [pscredential]$Credential = $__MtSession.AdCredential
    )

    if ('ActiveDirectory' -notin $__MtSession.Connections -and 'All' -notin $__MtSession.Connections ) {
        Write-Verbose "ActiveDirectory not set as connection"
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    if (-not $__MtSession.AdCache.AdDomains.SetFlag){
        Set-MtAdCache -Objects "Domains" -Server $Server -Credential $Credential
    }

    $AdObjects = $__MtSession.AdCache.AdDomains

    #region Collect
    foreach($domain in $AdObjects.Domains){
        $AdObjects."Data-$($domain.Name)".Name = $domain.Name

        $AdObjects."Data-$($domain.Name)".InfrastructureMaster = $domain.InfrastructureMaster
        $AdObjects."Data-$($domain.Name)".PDCEmulator = $domain.PDCEmulator
        $AdObjects."Data-$($domain.Name)".RIDMaster = $domain.RIDMaster
        $AdObjects."Data-$($domain.Name)".CommonFsmo = $domain.InfrastructureMaster -eq $domain.PDCEmulator -eq $domain.RIDMaster
    }
    #endregion

    $__MtSession.AdCache.AdDomains = $AdObjects

    #region Analysis
    $DomainTests = @()
    foreach($domain in $AdObjects.Domains){
        $Tests = @{
            Domain = $domain.Name
            CommonFsmo = @{
                Name        = "All domain-level FSMO roles are on a single DC"
                Value       = $AdObjects."Data-$($domain.Name)".CommonFsmo
                Threshold   = $true
                Indicator   = "="
                Description = "Checks that all domain-level FSMO roles are on a single DC"
                Status      = $null
            }
        }
        $DomainTests += $Tests
    }
    #endregion

    #region Processing
    foreach($domain in $DomainTests){
        foreach($test in $domain.GetEnumerator()|Where-Object{$_.Name -ne "Domain"}){
            switch($test.Value.Indicator){
                "=" {
                    $test.Value.Status = $test.Value.Value -eq $test.Value.Threshold
                }
                "<" {
                    $test.Value.Status = $test.Value.Value -lt $test.Value.Threshold
                }
                "<=" {
                    $test.Value.Status = $test.Value.Value -le $test.Value.Threshold
                }
                ">" {
                    $test.Value.Status = $test.Value.Value -gt $test.Value.Threshold
                }
                ">=" {
                    $test.Value.Status = $test.Value.Value -ge $test.Value.Threshold
                }
            }
        }
    }

    $result = $true
    $testResultMarkdown = $null
    foreach($domain in $DomainTests){
        foreach($test in $domain.GetEnumerator()|Where-Object{$_.Name -ne "Domain"}){
            [int]$result *= [int]$test.Value.Status

            $testResultMarkdown += "#### $($test.Value.Name)`n`n"
            $testResultMarkdown += "$($test.Value.Description)`n`n"
            $testResultMarkdown += "| Current State Value | Comparison | Threshold |`n"
            $testResultMarkdown += "| - | - | - |`n"
            $testResultMarkdown += "| $($test.Value.Value) | $($test.Value.Indicator) | $($test.Value.threshold) |`n`n"
            if($test.Value.Status){
                $testResultMarkdown += "Well done. Your current state is in alignment with the threshold.`n`n"
            }else{
                $testResultMarkdown += "Your current state is **NOT** in alignment with the threshold.`n`n"
            }
        }
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    return [bool]$result
    #endregion
}
