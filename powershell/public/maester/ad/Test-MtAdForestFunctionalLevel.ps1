<#
.SYNOPSIS
    Checks AD Forest Functional Level

.DESCRIPTION
    Identifies if forest functional level is high enough

.PARAMETER Server
    Server name to pass through to the AD Cmdlets

.PARAMETER Credential
    Credential object to pass through to the AD Cmdlets

.EXAMPLE
    Test-MtAdForestFunctionalLevel

    Returns true if AD Forest Functional Level is high enough

.LINK
    https://maester.dev/docs/commands/Test-MtAdForestFunctionalLevel
#>
function Test-MtAdForestFunctionalLevel {
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

    #endregion

    $__MtSession.AdCache.AdForest.Forest = $AdObjects.Forest
    $__MtSession.AdCache.AdForest.Data   = $AdObjects.Data

    #region Analysis
    $Tests = @{
        FunctionalLevel = @{
            Name        = "Forest Functional Level"
            Value       = [int]$AdObjects.Data.FunctionalLevel
            Threshold   = 7
            Indicator   = ">="
            Description = "Validates the Forest Functional Level is Windows 2016 or higher"
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
