<#
.SYNOPSIS
    Checks the computer objects for activity

.DESCRIPTION
    Checks the last logon for computer objects against multiple time periods

.EXAMPLE
    Test-MtAdComputerStatus

    Returns true if AD Computer status is within thresholds

.LINK
    https://maester.dev/docs/commands/Test-MtAdComputerStatus
#>
function Test-MtAdComputerStatus {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [string]$Server = $__MtSession.AdServer,
        [pscredential]$Credential = $__MtSession.AdCredential
    )

    if ('ActiveDirectory' -notin $__MtSession.Connections -and 'All' -notin $__MtSession.Connections ) {
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
    $AdObjects.Data.EnabledComputers = $AdObjects.Computers | Where-Object {
        $_.Enabled
    }
    $AdObjects.Data.EnabledComputersCount = ($AdObjects.Data.EnabledComputers | Measure-Object).Count

    $AdObjects.Data.DisabledComputers = $AdObjects.Computers | Where-Object {
        -not $_.Enabled
    }
    $AdObjects.Data.DisabledComputersCount = ($AdObjects.Data.DisabledComputers | Measure-Object).Count
    $AdObjects.Data.DisabledComputersRatio = try{
        $AdObjects.Data.DisabledComputersCount / $AdObjects.Data.ComputersCount
    }catch{0}

    $AdObjects.Data.DormantComputers = $AdObjects.Data.EnabledComputers | Where-Object {
        $_.LastLogonDate -lt $Thresholds.DormantDate
    }
    $AdObjects.Data.DormantComputersCount = ($AdObjects.Data.DormantComputers | Measure-Object).Count
    $AdObjects.Data.DormantComputersRatio = try{
        $AdObjects.Data.DormantComputersCount / $AdObjects.Data.EnabledComputersCount
    }catch{0}

    $AdObjects.Data.ExpiredComputers = $AdObjects.Data.EnabledComputers | Where-Object {
        $_.LastLogonDate -lt $Thresholds.ExpiredDate
    }
    $AdObjects.Data.ExpiredComputersCount = ($AdObjects.Data.ExpiredComputers | Measure-Object).Count
    $AdObjects.Data.ExpiredComputersRatio = try{
        $AdObjects.Data.ExpiredComputersCount / $AdObjects.Data.EnabledComputersCount
    }catch{0}

    $AdObjects.Data.StaleComputers = $AdObjects.Data.DisabledComputers | Where-Object {
        $_.Modified -lt $Thresholds.StaleDate
    }
    $AdObjects.Data.StaleComputersCount = ($AdObjects.Data.StaleComputers | Measure-Object).Count
    $AdObjects.Data.StaleComputersRatio = try{
        $AdObjects.Data.StaleComputersCount / $AdObjects.Data.DisabledComputersCount
    }catch{0}
    #endregion

    $__MtSession.AdCache.AdComputers.Computers = $AdObjects.Computers
    $__MtSession.AdCache.AdComputers.Data = $AdObjects.Data

    #region Analysis
    $Tests = @{
        DisabledComputers = @{
            Name        = "Disabled Computers"
            Value       = $AdObjects.Data.DisabledComputersRatio
            Threshold   = 0.05
            Indicator   = "<"
            Description = "Percent of all computer objects that are disabled"
            Status      = $null
        }
        StaleComputers = @{
            Name        = "Stale Computers"
            Value       = $AdObjects.Data.StaleComputersRatio
            Threshold   = 0.05
            Indicator   = "<"
            Description = "Percent of disabled computer objects with Modified before " + ($__MtSession.AdCache.Thresholds.StaleDate).ToString()
            Status      = $null
        }
        DormantComputers = @{
            Name        = "Dormant Computers"
            Value       = $AdObjects.Data.DormantComputersRatio
            Threshold   = 0.05
            Indicator   = "<"
            Description = "Percent of enabled computer objects with LastLogonDate before " + ($__MtSession.AdCache.Thresholds.DormantDate).ToString()
            Status      = $null
        }
        ExpiredComputers = @{
            Name        = "Expired Computers"
            Value       = $AdObjects.Data.ExpiredComputersRatio
            Threshold   = 0.05
            Indicator   = "<"
            Description = "Percent of enabled computer objects with LastLogonDate before " + ($__MtSession.AdCache.Thresholds.ExpiredDate).ToString()
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
