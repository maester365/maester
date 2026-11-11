function Test-MtAdGmsaAuthorizationEvidenceCompleteness {
    [MaesterTest(Id='AD-MSA-03',Title='gMSA managed-password authorization evidence should be complete and resolvable',Product='ad',Feature='account-security',Area='applications',ResourceType='Computer',Severity='Info',Mitre='None',Service='ActiveDirectory',Permission=('ActiveDirectory:Ldap:msDS-GroupManagedServiceAccount.msDS-GroupMSAMembership:ReadProperty'),Platform='Windows',Author='rolling-code')]
    [CmdletBinding()][OutputType([bool])]param()
    $state=Get-MtADDomainState -Categories ServiceAccounts
    if($null -eq $state){Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory;return $null}
    if($null -eq $state.ServiceAccounts){Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'ServiceAccounts collection failed or returned no state.';return $null}

    $incomplete=@($state.ServiceAccounts|Where-Object{-not $_.AuthorizationEvidenceComplete -or @($_.UnresolvedPasswordRetrievalTrustees).Count -gt 0})
    $table="| gMSA | Complete | Evidence status | Unresolved SID | Resolution status | Resolution error | Collection error |`n| --- | --- | --- | --- | --- | --- | --- |`n"
    foreach($gmsa in $incomplete){
        $unresolved=@($gmsa.UnresolvedPasswordRetrievalTrustees)
        if($unresolved.Count -eq 0){$table+="| $($gmsa.SamAccountName) | $($gmsa.AuthorizationEvidenceComplete) | $($gmsa.AuthorizationEvidenceStatus) |  |  |  | $($gmsa.AuthorizationCollectionError) |`n";continue}
        foreach($trustee in $unresolved){$table+="| $($gmsa.SamAccountName) | $($gmsa.AuthorizationEvidenceComplete) | $($gmsa.AuthorizationEvidenceStatus) | $($trustee.Sid) | $($trustee.ResolutionStatus) | $($trustee.ResolutionError) | $($gmsa.AuthorizationCollectionError) |`n"}
    }
    Add-MtTestResultDetail -Result "Found $($incomplete.Count) gMSA object(s) with incomplete or unresolved authorization evidence.`n`n$table" -Investigate
    return $true
}