<#
.SYNOPSIS
    Checks computer Kerberos configuration

.DESCRIPTION
    Identifies misconfigurations with computer objects and Kerberos

.PARAMETER Server
    Server name to pass through to the AD Cmdlets

.PARAMETER Credential
    Credential object to pass through to the AD Cmdlets

.EXAMPLE
    Test-MtAdComputerKerberos

    Returns true if AD Computer Kerberos is adequate

.LINK
    https://maester.dev/docs/commands/Test-MtAdComputerKerberos
#>
function Test-MtAdComputerKerberos {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Proper name')]
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
    $AdObjects.Data.UnconstrainedComputers = $AdObjects.Computers | Where-Object {
        $_.TrustedForDelegation -and
        $_.primaryGroupId -notin $AdObjects.Data.DomainControllerPgids
    }
    $AdObjects.Data.UnconstrainedComputersCount = ($AdObjects.Data.UnconstrainedComputers | Measure-Object).Count
    $AdObjects.Data.UnconstrainedComputersRatio = try{
        $AdObjects.Data.UnconstrainedComputersCount / $AdObjects.Data.ComputersCount
    }catch{0}

    $AdObjects.Data.KcdComputers = $AdObjects.Computers | Where-Object {
        -not $_.TrustedToAuthForDelegation -and
        $_.'msDS-AllowedToDelegateTo'.Count -ne 0
    }
    $AdObjects.Data.KcdComputersCount = ($AdObjects.Data.KcdComputers | Measure-Object).Count
    $AdObjects.Data.KcdComputersRatio = try{
        $AdObjects.Data.KcdComputersCount / $AdObjects.Data.ComputersCount
    }catch{0}

    $AdObjects.Data.S4U2SelfComputers = $AdObjects.Computers | Where-Object {
        $_.TrustedToAuthForDelegation -and
        $_.'msDS-AllowedToDelegateTo'.Count -ne 0
    }
    $AdObjects.Data.S4U2SelfComputersCount = ($AdObjects.Data.S4U2SelfComputers | Measure-Object).Count
    $AdObjects.Data.S4U2SelfComputersRatio = try{
        $AdObjects.Data.S4U2SelfComputersCount / $AdObjects.Data.ComputersCount
    }catch{0}

    $AdObjects.Data.RbcdComputers = $AdObjects.Computers | Where-Object {
        $_.PrincipalsAllowedToDelegateToAccount.Count -ne 0
    }
    $AdObjects.Data.RbcdComputersCount = ($AdObjects.Data.RbcdComputers | Measure-Object).Count
    $AdObjects.Data.RbcdComputersRatio = try{
        $AdObjects.Data.UnconstrainedComputersCount / $AdObjects.Data.ComputersCount
    }catch{0}

    $AdObjects.Data.MissingSpnsComputers = $AdObjects.Computers | Where-Object {
        ($_.TrustedForDelegation -or
        $_.TrustedToAuthForDelegation -or
        $_.'msDS-AllowedToDelegateTo'.Count -ne 0) -and
        $_.servicePrincipalName.Count -eq 0
    }
    $AdObjects.Data.MissingSpnsComputersCount = ($AdObjects.Data.MissingSpnsComputers | Measure-Object).Count
    $AdObjects.Data.MissingSpnsComputersRatio = try{
        $AdObjects.Data.UnconstrainedComputersCount / $AdObjects.Data.ComputersCount
    }catch{0}
    #endregion

    $__MtSession.AdCache.AdComputers.Data = $AdObjects.Data

    #region Analysis
    $Tests = @{
        UnconstrainedComputers = @{
            Name        = "Computers allowing unconstrained delegation"
            Value       = $AdObjects.Data.UnconstrainedComputersRatio
            Threshold   = 0.00
            Indicator   = "="
            Description = "Percent of computer objects allowing unconstrained Kerberos delegation (Excluding Domain Controllers)"
            Status      = $null
        }
        KcdComputers = @{
            Name        = "Computers allowing Kerberos Constrained Delegation"
            Value       = $AdObjects.Data.KcdComputersRatio
            Threshold   = 0.00
            Indicator   = ">="
            Description = "Percent of computer objects allowing Kerberos Constrained Delegation"
            Status      = $null
        }
        S4U2SelfComputers = @{
            Name        = "Computers allowing S4U2Self Kerberos Constrained Delegation"
            Value       = $AdObjects.Data.S4U2SelfComputersRatio
            Threshold   = 0.00
            Indicator   = ">="
            Description = "Percent of computer objects allowing Kerberos Constrained Delegation with Protocol Transition (i.e. S4U2Self)"
            Status      = $null
        }
        RbcdComputers = @{
            Name        = "Computers allowing Kerberos Resource Based Constrained Delegation"
            Value       = $AdObjects.Data.RbcdComputersRatio
            Threshold   = 0.00
            Indicator   = ">="
            Description = "Percent of computer objects allowing Resource-based Constrained Delegation (i.e., S4U2proxy) Kerberos delegation"
            Status      = $null
        }
        MissingSpnsComputers = @{
            Name        = "Computers allowing delegation with no SPNs"
            Value       = $AdObjects.Data.MissingSpnsComputersRatio
            Threshold   = 0.00
            Indicator   = "="
            Description = "Percent of computer objects allowing Kerberos delegation but without any SPNs"
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
