<#
.SYNOPSIS
    Checks AD Domain default containers

.DESCRIPTION
    Identifies if default containers are still set

.PARAMETER Server
    Server name to pass through to the AD Cmdlets

.PARAMETER Credential
    Credential object to pass through to the AD Cmdlets

.EXAMPLE
    Test-MtAdDomainContainer

    Returns true if default containers have been updated

.LINK
    https://maester.dev/docs/commands/Test-MtAdDomainContainer
#>
function Test-MtAdDomainContainer {
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

        $AdObjects."Data-$($domain.Name)".ComputersContainer = $domain.ComputersContainer
        $AdObjects."Data-$($domain.Name)".DefaultComputersContainer = $domain.ComputersContainer -like "CN=Computers,$($domain.DistinguishedName)"

        $AdObjects."Data-$($domain.Name)".UsersContainer = $domain.UsersContainer
        $AdObjects."Data-$($domain.Name)".DefaultUsersContainerContainer = $domain.UsersContainer -like "CN=Users,$($domain.DistinguishedName)"

        $AdObjects."Data-$($domain.Name)".DomainControllersContainer = $domain.DomainControllersContainer
        $AdObjects."Data-$($domain.Name)".DefaultDomainControllersContainer = $domain.DomainControllersContainer -like "OU=Domain Controllers,$($domain.DistinguishedName)"
    }
    #endregion

    $__MtSession.AdCache.AdDomains = $AdObjects

    #region Analysis
    $DomainTests = @()
    foreach($domain in $AdObjects.Domains){
        $Tests = @{
            Domain = $domain.Name
            DefaultComputersContainer = @{
                Name        = "Checks configuration of default computers container"
                Value       = $AdObjects."Data-$($domain.Name)".DefaultComputersContainer
                Threshold   = $false
                Indicator   = "="
                Description = "Checks that the default computers container is not in use"
                Status      = $null
            }
            DefaultUsersContainerContainer = @{
                Name        = "Checks configuration of default users container"
                Value       = $AdObjects."Data-$($domain.Name)".DefaultUsersContainerContainer
                Threshold   = $false
                Indicator   = "="
                Description = "Checks that the default users container is not in use"
                Status      = $null
            }
            DefaultDomainControllersContainer = @{
                Name        = "Checks configuration of default domain controllers container"
                Value       = $AdObjects."Data-$($domain.Name)".DefaultDomainControllersContainer
                Threshold   = $false
                Indicator   = "="
                Description = "Checks that the default domain controllers container is not in use"
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
