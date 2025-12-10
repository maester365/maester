<#
.SYNOPSIS
    Checks the primary group IDs of computers

.DESCRIPTION
    Identifies if any computer objects do not have a normal primary group ID

.PARAMETER Server
    Server name to pass through to the AD Cmdlets

.PARAMETER Credential
    Credential object to pass through to the AD Cmdlets

.EXAMPLE
    Test-MtAdComputerPrimaryGroup

    Returns true if AD Computer primary groups are all default

.LINK
    https://maester.dev/docs/commands/Test-MtAdComputerPrimaryGroup
#>
function Test-MtAdComputerPrimaryGroup {
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

    if (-not $__MtSession.AdCache.AdComputers.SetFlag){
        Set-MtAdCache -Objects "Computers" -Server $Server -Credential $Credential
    }

    $AdObjects = @{
        Computers = $__MtSession.AdCache.AdComputers.Computers
        Data      = $__MtSession.AdCache.AdComputers.Data
    }

    #region Collect
    $AdObjects.Data.NonPgIdCoumputers = $AdObjects.Computers | Where-Object {
        $_.primaryGroupId -notin $__MtSession.AdCache.PrimaryGroupIds
    }
    $AdObjects.Data.NonPgIdCoumputersCount = ($AdObjects.Data.NonPgIdCoumputers | Measure-Object).Count
    $AdObjects.Data.NonPgIdComputersRatio = try{
        $AdObjects.Data.NonPgIdCoumputersCount / $AdObjects.Data.ComputersCount
    }catch{0}
    #endregion

    $__MtSession.AdCache.AdComputers.Computers = $AdObjects.Computers
    $__MtSession.AdCache.AdComputers.Data = $AdObjects.Data

    #region Analysis
    $Tests = @{
        NonPgIdCoumputers = @{
            Name        = "Computers with non-default Primary Group ID"
            Value       = $AdObjects.Data.NonPgIdCoumputersRatio
            Threshold   = 0.00
            Indicator   = "="
            Description = "Percent of computer objects with a Primary Group ID other than " + ($__MtSession.AdCache.PrimaryGroupIds -join ", ").ToString()
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
