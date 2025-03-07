<#
.SYNOPSIS
    Checks if passwords are set to not expire

.DESCRIPTION
    User passwords SHALL NOT expire.

.EXAMPLE
    Test-MtCisaPasswordExpiration

    Returns true if all verified managed domains have password expiration configured
    to be of 100 years or greater

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

    $verifiedDomains = $result | Where-Object isVerified

    $managedDomains = $verifiedDomains | Where-Object authenticationType -eq "Managed"

    $compliantDomains = $managedDomains | Where-Object PasswordValidityPeriodInDays -ge 36500

    $testResult = ($managedDomains | Measure-Object).Count - ($compliantDomains | Measure-Object).Count -eq 0

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant password expiration policy is set to never expire.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have password expiration set to never expire.`n`n%TestResult%"
    }

    $pass = "✅ Pass"
    $fail = "❌ Fail"
    $skip = "🗄️ Skipped"
    $default = "✔️"

    $resultDetails = "| Domain (Default) | Verified | Type | Validation |`n"
    $resultDetails += "| --- | --- | --- | --- |`n"
    foreach($domain in $result){
        if($domain.isDefault){
            $isDefault = "$($domain.id) ($default)"
        }else{
            $isDefault = "$($domain.id) ()"
        }
        if($domain.isVerified){
            $isVerified = "Verified"
        }else{
            $isVerified = "Unverified"
        }
        if($domain.id -in $compliantDomains.id){
            $testValue = $pass
        }elseif($domain.authenticationType -eq "Federated"){
            $testValue = $skip
        }elseif($isVerified -eq "Unverified"){
            $testValue = $skip
        }else{
            $testValue = $fail
        }

        $resultDetails += "| $isDefault | $isVerified | $($domain.authenticationType) | $testValue |`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $resultDetails

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
