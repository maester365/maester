<#
.SYNOPSIS
    Checks if passwords are set to not expire

.DESCRIPTION

    User passwords SHALL NOT expire.

.EXAMPLE
    Test-MtCisaPasswordExpiration

    Returns true if at least 1 domain has password expiration of 100 years or greater
#>

Function Test-MtCisaPasswordExpiration {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

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

    $testResult = $managedDomains.Count -ge 1

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has at least 1 managed domain with a password validity of 100 years or greater:`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not prevent password expiration."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjectType Domains -GraphObjects $managedDomains

    return $testResult
}