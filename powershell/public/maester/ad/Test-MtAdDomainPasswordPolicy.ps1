<#
.SYNOPSIS
    Checks AD Domain Password Policies

.DESCRIPTION
    Identifies if Domain password policies are set

.PARAMETER Server
    Server name to pass through to the AD Cmdlets

.PARAMETER Credential
    Credential object to pass through to the AD Cmdlets

.EXAMPLE
    Test-MtAdDomainPasswordPolicy

    Returns true if default domain password policy has been modified
    and passwords are auto-rotated for passwordless users

.LINK
    https://maester.dev/docs/commands/Test-MtAdDomainPasswordPolicy
#>
function Test-MtAdDomainPasswordPolicy {
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

        $AdObjects."Data-$($domain.Name)".PublicKeyRequiredPasswordRolling = $domain.PublicKeyRequiredPasswordRolling
    }

    foreach($domainObject in $AdObjects.DomainObjects){
        $AdObjects."Data-$($domainObject.Name)".ForceLogoff = $domainObject.ForceLogoff
        #-9223372036854775808 is the maximum value for a 64-bit signed integer
        $AdObjects."Data-$($domainObject.Name)".IsDefaultForceLogoff = (-9223372036854775808 -eq $domainObject.ForceLogoff)

        $AdObjects."Data-$($domainObject.Name)".LockoutDuration = $domainObject.LockoutDuration
        #-6000000000 is nanosecond representation for minutes
        $AdObjects."Data-$($domainObject.Name)".IsDefaultLockoutDuration = (-6000000000 -eq $domainObject.LockoutDuration)

        $AdObjects."Data-$($domainObject.Name)".LockOutObservationWindow = $domainObject.LockOutObservationWindow
        #-6000000000 is nanosecond representation for minutes
        $AdObjects."Data-$($domainObject.Name)".IsDefaultLockOutObservationWindow = (-6000000000 -eq $domainObject.LockOutObservationWindow)

        $AdObjects."Data-$($domainObject.Name)".LockoutThreshold = $domainObject.LockoutThreshold
        $AdObjects."Data-$($domainObject.Name)".IsDefaultLockoutThreshold = (0 -eq $domainObject.LockoutThreshold)

        $AdObjects."Data-$($domainObject.Name)".MaxPwdAge = $domainObject.MaxPwdAge
        #-36288000000000 is the number of 100-nanosecond intervals
        #-36288000000000*100 = -3628800000000000 nanoseconds / 8.64e+13 = -42 days
        $AdObjects."Data-$($domainObject.Name)".IsDefaultMaxPwdAge = (-36288000000000 -eq $domainObject.MaxPwdAge)

        $AdObjects."Data-$($domainObject.Name)".MinPwdAge = $domainObject.MinPwdAge
        #-864000000000 is the number of 100-nanosecond intervals
        #-864000000000*100 = -86400000000000 nanoseconds / 8.64e+13 = -1 days
        $AdObjects."Data-$($domainObject.Name)".IsDefaultMinPwdAge = (-864000000000 -eq $domainObject.MinPwdAge)

        $AdObjects."Data-$($domainObject.Name)".MinPwdLength = $domainObject.MinPwdLength
        $AdObjects."Data-$($domainObject.Name)".IsDefaultMinPwdLength = (7 -eq $domainObject.MinPwdLength)

        $AdObjects."Data-$($domainObject.Name)".PwdHistoryLength = $domainObject.PwdHistoryLength
        $AdObjects."Data-$($domainObject.Name)".IsDefaultPwdHistoryLength = (24 -eq $domainObject.PwdHistoryLength)

        $AdObjects."Data-$($domainObject.Name)".DefaultPasswordPolicy = $false -notin @(
            $AdObjects."Data-$($domainObject.Name)".IsDefaultForceLogoff,
            $AdObjects."Data-$($domainObject.Name)".IsDefaultLockoutDuration,
            $AdObjects."Data-$($domainObject.Name)".IsDefaultLockOutObservationWindow,
            $AdObjects."Data-$($domainObject.Name)".IsDefaultLockoutThreshold,
            $AdObjects."Data-$($domainObject.Name)".IsDefaultMaxPwdAge,
            $AdObjects."Data-$($domainObject.Name)".IsDefaultMinPwdAge,
            $AdObjects."Data-$($domainObject.Name)".IsDefaultMinPwdLength,
            $AdObjects."Data-$($domainObject.Name)".IsDefaultPwdHistoryLength
        )
    }
    #endregion

    $__MtSession.AdCache.AdDomains = $AdObjects

    #region Analysis
    $DomainTests = @()
    foreach($domain in $AdObjects.Domains){
        $Tests = @{
            Domain = $domain.Name
            PublicKeyRequiredPasswordRolling = @{
                Name        = "Require password rotation for passwordless accounts"
                Value       = $AdObjects."Data-$($domain.Name)".PublicKeyRequiredPasswordRolling
                Threshold   = $true
                Indicator   = "="
                Description = "Checks that passwords on accounts configured for passwordless are automatically rotated"
                Status      = $null
            }
            DefaultPasswordPolicy = @{
                Name        = "Checks state of domain password policy"
                Value       = $AdObjects."Data-$($domain.Name)".DefaultPasswordPolicy
                Threshold   = $false
                Indicator   = "="
                Description = "Checks that the domain password policy has been updated"
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
