function Test-MtCisaPasswordExpiration {
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
    $legacyManagedDomains = $managedDomains | Where-Object {
        $supportedServices = @($_.supportedServices)
        ($supportedServices.Count -eq 1) -and ($supportedServices -contains "SharePoint")
    }
    $applicableManagedDomains = $managedDomains | Where-Object {
        $_.id -notin $legacyManagedDomains.id
    }
    $noPasswordExpiryPeriodInDays = [int]::MaxValue

    # Password expiration is compliant only when it is explicitly set to never expire.
    $compliantDomains = $applicableManagedDomains | Where-Object {
        $passwordValidityPeriodInDays = 0
        $domainPasswordValidityPeriodInDays = $_.PasswordValidityPeriodInDays

        if (($null -eq $domainPasswordValidityPeriodInDays) -or ($domainPasswordValidityPeriodInDays -is [bool])) {
            return $false
        }

        if (-not [int]::TryParse($domainPasswordValidityPeriodInDays.ToString(), [ref]$passwordValidityPeriodInDays)) {
            return $false
        }

        return $passwordValidityPeriodInDays -eq $noPasswordExpiryPeriodInDays
    }

    $testResult = ($applicableManagedDomains | Measure-Object).Count - ($compliantDomains | Measure-Object).Count -eq 0

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant password expiration policy is set to never expire.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant has 1 or more managed domains where password expiration is not explicitly set to never expire.`n`n%TestResult%"
    }

    $pass = "✅ Pass"
    $fail = "❌ Fail"
    $skip = "🗄️ Skipped"
    $default = "✔️"

    $resultDetails = "| Domain (Default) | Verified | Type | Validation | Reason |`n"
    $resultDetails += "| --- | --- | --- | --- | --- |`n"
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
            $reason = ""
        }elseif($domain.authenticationType -eq "Federated"){
            $testValue = $skip
            $reason = "Federated domain"
        }elseif($domain.id -in $legacyManagedDomains.id){
            $testValue = $skip
            $reason = "Legacy SharePoint-only domain"
        }elseif($isVerified -eq "Unverified"){
            $testValue = $skip
            $reason = "Unverified domain"
        }else{
            $testValue = $fail
            $reason = "Password expiration is not explicitly set to never expire"
        }

        $resultDetails += "| $isDefault | $isVerified | $($domain.authenticationType) | $testValue | $reason |`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $resultDetails

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
