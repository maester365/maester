<#
.SYNOPSIS
    Checks AD Domain structure

.DESCRIPTION
    Identifies if DCs, RODCs, and child domains are adequate

.PARAMETER Server
    Server name to pass through to the AD Cmdlets

.PARAMETER Credential
    Credential object to pass through to the AD Cmdlets

.EXAMPLE
    Test-MtAdDomainStructure

    Returns true if no RODCs and >= 2 DCs

.LINK
    https://maester.dev/docs/commands/Test-MtAdDomainStructure
#>
function Test-MtAdDomainStructure {
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

        $AdObjects."Data-$($domain.Name)".ChildDomains = $domain.ChildDomains
        $AdObjects."Data-$($domain.Name)".ChildDomainsCount = ($AdObjects."Data-$($domain.Name)".ChildDomains | Measure-Object).Count

        $AdObjects."Data-$($domain.Name)".ReadOnlyDomainControllers = $domain.ReadOnlyReplicaDirectoryServers
        $AdObjects."Data-$($domain.Name)".ReadOnlyDomainControllersCount = ($AdObjects."Data-$($domain.Name)".ReadOnlyDomainControllers | Measure-Object).Count

        $AdObjects."Data-$($domain.Name)".DomainControllers = $domain.ReplicaDirectoryServers
        $AdObjects."Data-$($domain.Name)".DomainControllersCount = ($AdObjects."Data-$($domain.Name)".DomainControllers | Measure-Object).Count

        $AdObjects."Data-$($domain.Name)".ParentDomain = $domain.ParentDomain
        $AdObjects."Data-$($domain.Name)".IsRootDomain = ($null -eq $domain.ParentDomain)
    }
    #endregion

    $__MtSession.AdCache.AdDomains = $AdObjects

    #region Analysis
    $DomainTests = @()
    foreach($domain in $AdObjects.Domains){
        $Tests = @{
            Domain = $domain.Name
            ReadOnlyDomainControllersCount = @{
                Name        = "Number of RODCs"
                Value       = $AdObjects."Data-$($domain.Name)".ReadOnlyDomainControllersCount
                Threshold   = 0
                Indicator   = "="
                Description = "Checks that Read Only Domain Controllers (RODC) are not in use"
                Status      = $null
            }
            DomainControllersCount = @{
                Name        = "Number of writeable DCs"
                Value       = $AdObjects."Data-$($domain.Name)".DomainControllersCount
                Threshold   = 2
                Indicator   = ">="
                Description = "Checks that at least 2 writeable domain controllers are in use"
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
