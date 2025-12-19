<#
.SYNOPSIS
    Checks AD Domain machine account quota

.DESCRIPTION
    Identifies if domain machine account quota is set

.PARAMETER Server
    Server name to pass through to the AD Cmdlets

.PARAMETER Credential
    Credential object to pass through to the AD Cmdlets

.EXAMPLE
    Test-MtAdDomainMachineAccountQuota

    Returns true if AD machine account quota is 0

.LINK
    https://maester.dev/docs/commands/Test-MtAdDomainMachineAccountQuota
#>
function Test-MtAdDomainMachineAccountQuota {
    [CmdletBinding()]
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

        $AdObjects."Data-$($domain.Name)".MachineAccountQuota = $domain.MachineAccountQuota
        $AdObjects."Data-$($domain.Name)".IsDefaultMachineAccountQuota = (10 -eq $domain.MachineAccountQuota)
    }
    #endregion

    $__MtSession.AdCache.AdDomains = $AdObjects

    #region Analysis
    $DomainTests = @()
    foreach($domain in $AdObjects.Domains){
        $Tests = @{
            Domain = $domain.Name
            MachineAccountQuota = @{
                Name        = "Machine Account Quota"
                Value       = $AdObjects."Data-$($domain.Name)".MachineAccountQuota
                Threshold   = 0
                Indicator   = "="
                Description = "Checks that the default machine account quota is disabled"
                Status      = $null
            }
            IsDefaultMachineAccountQuota = @{
                Name        = "Machine Account Quota Default"
                Value       = $AdObjects."Data-$($domain.Name)".IsDefaultMachineAccountQuota
                Threshold   = $false
                Indicator   = "="
                Description = "Checks that the default machine account quota is not the default"
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
