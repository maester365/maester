function Test-MtAdGmsaAuthorizationEvidenceCompleteness {
    [MaesterTest(Id='AD-MSA-03',Title='gMSA managed-password authorization evidence should be complete and resolvable',Product='ad',Feature='account-security',Area='privileged-access',ResourceType='Computer',Severity='Info',Mitre='None',Service='ActiveDirectory',Permission=('ActiveDirectory:Ldap:msDS-GroupManagedServiceAccount.msDS-GroupMSAMembership:ReadProperty'),Platform='Windows',Author='rolling-code')]
    [CmdletBinding()][OutputType([bool])]param()
    $state=Get-MtADDomainState -Categories ServiceAccounts
    if($null -eq $state){Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory;return $null}
    $incomplete=@($state.ServiceAccounts|Where-Object{-not $_.AuthorizationEvidenceComplete -or @($_.UnresolvedPasswordRetrievalTrustees).Count -gt 0})
    $table="| gMSA | Complete | Evidence status | Unresolved trustees | Error |`n| --- | --- | --- | ---: | --- |`n";foreach($i in $incomplete){$table+="| $($i.SamAccountName) | $($i.AuthorizationEvidenceComplete) | $($i.AuthorizationEvidenceStatus) | $(@($i.UnresolvedPasswordRetrievalTrustees).Count) | $($i.AuthorizationCollectionError) |`n"}
    Add-MtTestResultDetail -Result "Found $($incomplete.Count) gMSA object(s) with incomplete or unresolved authorization evidence.`n`n$table" -Investigate
    return $true
}