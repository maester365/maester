function Test-MtCisaPasswordExpirationCompliance {
    <#
    .SYNOPSIS
    Checks if passwords are set to not expire

    .DESCRIPTION
    User passwords SHALL NOT expire.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisaPasswordExpirationCompliance
    if ($result -eq $true) { Write-Host "Compliant" }
    elseif ($result -eq $false) { Write-Host "Non-Compliant" }
    else { Write-Host "Skipped or Error" }

    .OUTPUTS
    bool|null - Returns true if compliant, false if non-compliant, null if skipped or error
    #>
    [CmdletBinding()]
    [OutputType([bool], [nullable])]
    param()

    # Phase 1: Prerequisites Check
    try {
        $graphContext = Get-MgContext
        if ($null -eq $graphContext) {
            Write-Verbose "Not connected to Microsoft Graph"
            return $null
        }
    } catch {
        Write-Verbose "Microsoft Graph connection check failed: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation

    $result = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/domains'.0

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


    return $testResult

}
