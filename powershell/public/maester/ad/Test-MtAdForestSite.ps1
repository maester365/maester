<#
.SYNOPSIS
    Checks AD Forest Sites

.DESCRIPTION
    Identifies if forest has Sites

.PARAMETER Server
    Server name to pass through to the AD Cmdlets

.PARAMETER Credential
    Credential object to pass through to the AD Cmdlets

.EXAMPLE
    Test-MtAdForestSite

    Returns true if AD Forest has sites

.LINK
    https://maester.dev/docs/commands/Test-MtAdForestSite
#>
function Test-MtAdForestSite {
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

    if (-not $__MtSession.AdCache.AdForest.SetFlag){
        Set-MtAdCache -Objects "Forest" -Server $Server -Credential $Credential
    }

    $AdObjects = @{
        Forest = $__MtSession.AdCache.AdForest.Forest
        Data   = $__MtSession.AdCache.AdForest.Data
    }

    #region Collect
    $AdObjects.Data.Sites = @($AdObjects.Forest.Sites)
    $AdObjects.Data.SitesCount = ($AdObjects.Data.Sites | Measure-Object).Count
    $AdObjects.Data.DefaultSite = ($AdObjects.Data.Sites -contains "Default-First-Site-Name")
    #endregion

    $__MtSession.AdCache.AdForest.Data   = $AdObjects.Data

    #region Analysis
    $Tests = @{
        Sites = @{
            Name        = "Sites configured"
            Value       = $AdObjects.Data.Sites
            Threshold   = 2
            Indicator   = ">="
            Description = "Discrete number of sites within the forest"
            Status      = $null
        }
        DefaultSite = @{
            Name        = "Default site exists"
            Value       = $AdObjects.Data.Sites
            Threshold   = $true
            Indicator   = "="
            Description = "Validates the Default-First-Site-Name exists"
            Status      = $null
        }
    }
    #endregion

    #region Processing
    foreach($test in $Tests.GetEnumerator()){
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

    $result = $true
    $testResultMarkdown = $null
    foreach($test in $Tests.GetEnumerator()){
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

    Add-MtTestResultDetail -Result $testResultMarkdown
    return [bool]$result
    #endregion
}
