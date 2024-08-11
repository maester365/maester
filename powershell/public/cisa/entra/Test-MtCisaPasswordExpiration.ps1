<#
.SYNOPSIS
    Checks if passwords are set to not expire

.DESCRIPTION
    User passwords SHALL NOT expire.

.EXAMPLE
    Test-MtCisaPasswordExpiration

    Returns true if at least 1 domain has password expiration of 100 years or greater

.LINK
    https://maester.dev/docs/commands/Test-MtCisaPasswordExpiration
#>
function Test-MtCisaPasswordExpiration {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if(!(Test-MtConnection Graph)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    $result = Invoke-MtGraphRequest -RelativeUri "domains" -ApiVersion v1.0

    #Would need to validate management API is configured
    #https://admin.microsoft.com/admin/api/Settings/security/passwordpolicy
    #"NeverExpire": true

    #Would need to validate user level passwordPolicies
    #$users = Get-MgUser -All -Property PasswordPolicies
    #$users|?{$_.PasswordPolicies -like "*DisablePasswordExpiration*"}

    #Would need to handle exception for federated domains
    #$federatedDomains = $result | Where-Object {`
    #    $_.authenticationType -ne "Managed"}

    $managedDomains = $result | Where-Object {`
        $_.authenticationType -eq "Managed" -and `
        $_.PasswordValidityPeriodInDays -ge 36500}

    $testResult = ($managedDomains|Measure-Object).Count -ge 1

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant password expiration policy is set to never expire."
    } else {
        $testResultMarkdown = "Your tenant does not have password expiration set to never expire."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}