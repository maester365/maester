<#
.SYNOPSIS
    Checks AD Computer Containers

.DESCRIPTION
    Identifies if computer containers are misused

.EXAMPLE
    Test-MtAdComputerContainer

    Returns true if AD Computer containers are clean

.LINK
    https://maester.dev/docs/commands/Test-MtAdComputerContainer
#>
function Test-MtAdComputerContainer {
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
    $AdObjects.Data.ContainerComputers = $AdObjects.Computers | Where-Object {
        $_.DistinguishedName -like "*CN=Computers*"
    }
    $AdObjects.Data.ContainerComputersCount = ($AdObjects.Data.ContainerComputers | Measure-Object).Count
    $AdObjects.Data.ContainerComputersRatio = try{
        $AdObjects.Data.ContainerComputersCount / $AdObjects.Data.ComputersCount
    }catch{0}

    $AdObjects.Data.BaseDns = $AdObjects.Computers | Select-Object @{
        Name       = "BaseDN"
        Expression = {($_.DistinguishedName).Substring(($_.DistinguishedName).IndexOf(",")+1)}
    } | Group-Object BaseDN
    $AdObjects.Data.BaseDnCount = ($AdObjects.Data.BaseDns | Measure-Object).Count
    $AdObjects.Data.BaseDnAvg   = try{
        [Math]::Round($AdObjects.Data.ComputersCount / $AdObjects.Data.BaseDnCount,2)
    }catch{0}
    $AdObjects.Data.LowBaseDns  = $AdObjects.Data.BaseDns | Where-Object {
        $_.Count -lt $AdObjects.Data.BaseDnAvg
    }
    $AdObjects.Data.LowBaseDnsCount = ($AdObjects.Data.LowBaseDns | Measure-Object).Count
    #endregion

    $__MtSession.AdCache.AdComputers.Computers = $AdObjects.Computers
    $__MtSession.AdCache.AdComputers.Data = $AdObjects.Data

    #region Analysis
    $Tests = @{
        ContainerComputers = @{
            Name        = "Computers within the Computers Container"
            Value       = $AdObjects.Data.ContainerComputersRatio
            Threshold   = 0.00
            Indicator   = "="
            Description = "Percent of computer objects within the Computers Container"
            Status      = $null
        }
        BaseDns = @{
            Name        = "Distinct Containers with Computers"
            Value       = $AdObjects.Data.BaseDnCount
            Threshold   = 5
            Indicator   = "<"
            Description = "Number of containers that hold computer objects"
            Status      = $null
        }
        ComputerCnDensity = @{
            Name        = "Density of Computers in Containers"
            Value       = $AdObjects.Data.BaseDnAvg
            Threshold   = 1
            Indicator   = ">"
            Description = "Average number of computers per container"
            Status      = $null
        }
        LowBaseDns = @{
            Name        = "Containers with below average number of computers"
            Value       = $AdObjects.Data.LowBaseDnsCount
            Threshold   = 1
            Indicator   = "<="
            Description = "Number of containers that hold fewer than the average number of computers in containers"
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
