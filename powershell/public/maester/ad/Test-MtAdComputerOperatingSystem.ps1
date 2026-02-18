<#
.SYNOPSIS
    Checks computer operating systems

.DESCRIPTION
    Identifies issues with computer object operating systems

.PARAMETER Server
    Server name to pass through to the AD Cmdlets

.PARAMETER Credential
    Credential object to pass through to the AD Cmdlets

.EXAMPLE
    Test-MtAdComputerOperatingSystem

    Returns true if AD Computer operating systems are clean

.LINK
    https://maester.dev/docs/commands/Test-MtAdComputerOperatingSystem
#>
function Test-MtAdComputerOperatingSystem {
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
    $AdObjects.Data.OperatingSystems = $AdObjects.Computers | Group-Object OperatingSystem
    $AdObjects.Data.OperatingSystemsCount = ($AdObjects.Data.OperatingSystems | Measure-Object).Count

    $AdObjects.Data.NoOperatingSystem = $AdObjects.Data.OperatingSystems | Where-Object {
        $_.Name -eq ""
    }
    $AdObjects.Data.NoOperatingSystemCount = $AdObjects.Data.NoOperatingSystem.Count
    $AdObjects.Data.NoOperatingSystemRatio = try{
        $AdObjects.Data.NoOperatingSystemCount / $AdObjects.Data.ComputersCount
    }catch{0}

    $AdObjects.Data.OperatingSystemAvg = [Math]::Round($AdObjects.Data.ComputersCount / $AdObjects.Data.OperatingSystemsCount,2)
    $AdObjects.Data.LowOperatingSystem  = $AdObjects.Data.OperatingSystems | Where-Object {
        $_.Count -lt $AdObjects.Data.OperatingSystemAvg
    }
    $AdObjects.Data.LowOperatingSystemCount = ($AdObjects.Data.LowOperatingSystem | Measure-Object).Count
    $AdObjects.Data.OperatingSystemAvg = try{
        [Math]::Round($AdObjects.Data.ComputersCount / $AdObjects.Data.OperatingSystemsCount,2)
    }catch{0}
    #endregion

    $__MtSession.AdCache.AdComputers.Data = $AdObjects.Data

    #region Analysis
    $Tests = @{
        OperatingSystems = @{
            Name        = "Operating systems observed"
            Value       = $AdObjects.Data.OperatingSystemsCount
            Threshold   = 0.00
            Indicator   = ">"
            Description = "Discrete number of operating systems observed in use"
            Status      = $null
        }
        NoOperatingSystem = @{
            Name        = "Computers without an operating system set"
            Value       = $AdObjects.Data.NoOperatingSystemRatio
            Threshold   = 0.00
            Indicator   = "="
            Description = "Percent of computer objects without an operating system set"
            Status      = $null
        }
        OperatingSystemAvg = @{
            Name        = "Density of Computer operating systems"
            Value       = $AdObjects.Data.OperatingSystemAvg
            Threshold   = 1
            Indicator   = ">="
            Description = "Average number of computers per operating system"
            Status      = $null
        }
        LowOperatingSystem = @{
            Name        = "Operating systems with below average number of computers"
            Value       = $AdObjects.Data.LowOperatingSystemCount
            Threshold   = 1
            Indicator   = "<="
            Description = "Number of operating systems that with fewer than the average number of computers"
            Status      = $null
        }
    }
    #endregion

    # TODO
    # Check DACLs for restrictions to modify property msDS-AllowedToDelegateTo
    # Check DACLs for restrictions to modify property PrincipalsAllowedToDelegateToAccount

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
