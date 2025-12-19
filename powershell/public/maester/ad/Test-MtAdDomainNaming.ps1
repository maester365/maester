<#
.SYNOPSIS
    Checks AD Domain names

.DESCRIPTION
    Identifies if domain names meet requirements

.PARAMETER Server
    Server name to pass through to the AD Cmdlets

.PARAMETER Credential
    Credential object to pass through to the AD Cmdlets

.EXAMPLE
    Test-MtAdDomainNaming

    Returns true if AD Domain names meet requirements

.LINK
    https://maester.dev/docs/commands/Test-MtAdDomainNaming
#>
function Test-MtAdDomainNaming {
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

        $AdObjects."Data-$($domain.Name)".NetBIOSName = $domain.NetBIOSName
        #Standards for internet domain names (RFCs 952, 1035, 1123)
        $AdObjects."Data-$($domain.Name)".IsNetBIOSNameCompliant = ($domain.NetBIOSName -match "^([a-zA-Z0-9]{0,15})?$")

        $AdObjects."Data-$($domain.Name)".DNSRoot = $domain.DNSRoot
        $AdObjects."Data-$($domain.Name)".IsDNSRootCompliant = ($domain.DNSRoot -match "^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?$")

        $AdObjects."Data-$($domain.Name)".AllowedDNSSuffixes = $domain.AllowedDNSSuffixes
        $AdObjects."Data-$($domain.Name)".AllowedDNSSuffixesCount = ($AdObjects."Data-$($domain.Name)".AllowedDNSSuffixes | Measure-Object).Count
    }
    #endregion

    $__MtSession.AdCache.AdDomains = $AdObjects

    #region Analysis
    $DomainTests = @()
    foreach($domain in $AdObjects.Domains){
        $Tests = @{
            Domain = $domain.Name
            IsNetBIOSNameCompliant = @{
                Name        = "NetBIOS Name aligns with standards"
                Value       = $AdObjects."Data-$($domain.Name)".IsNetBIOSNameCompliant
                Threshold   = $true
                Indicator   = "="
                Description = "Checks the NetBIOS Name alignment with RFCs"
                Status      = $null
            }
            IsDNSRootCompliant = @{
                Name        = "DNS Root aligns with standards"
                Value       = $AdObjects."Data-$($domain.Name)".IsDNSRootCompliant
                Threshold   = $true
                Indicator   = "="
                Description = "Checks the DNS Root alignment with RFCs"
                Status      = $null
            }
            AllowedDNSSuffixesCount = @{
                Name        = "DNS Suffixes allowed"
                Value       = $AdObjects."Data-$($domain.Name)".AllowedDNSSuffixesCount
                Threshold   = 0
                Indicator   = ">="
                Description = "Checks the number of DNS Suffixes configured"
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
