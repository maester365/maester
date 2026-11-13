function Test-MtAdGmsaBroadPasswordRetrievalAuthorization {
    [MaesterTest(Id='AD-MSA-02',Title='Broad principals should not be authorized to retrieve gMSA managed passwords',Product='ad',Feature='account-security',Area='applications',ResourceType='Computer',Severity='High',UserImpact='Low',ImplementationCost='Medium',Mitre=('T1555'),Service='ActiveDirectory',Permission=('ActiveDirectory:Ldap:msDS-GroupManagedServiceAccount.msDS-GroupMSAMembership:ReadProperty'),Platform='Windows',Author='rolling-code')]
    [CmdletBinding()][OutputType([bool])]param()
    $state=Get-MtADDomainState -Categories ServiceAccounts
    if($null -eq $state){Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory;return $null}
    if($null -eq $state.ServiceAccounts){Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'ServiceAccounts collection failed or returned no state.';return $null}

    $incomplete=@($state.ServiceAccounts|Where-Object{-not $_.AuthorizationEvidenceComplete})
    $items=@($state.ServiceAccounts|ForEach-Object{$gmsa=$_;@($gmsa.BroadPasswordRetrievalTrustees)|ForEach-Object{[pscustomobject]@{Account=$gmsa.SamAccountName;Trustee=$_.Name;Sid=$_.Sid;Source=$_.AuthorizationSource}}})
    $table="| gMSA | Trustee | SID | Source |`n| --- | --- | --- | --- |`n";foreach($i in $items){$table+="| $($i.Account) | $($i.Trustee) | $($i.Sid) | $($i.Source) |`n"}
    if($items.Count -gt 0){Add-MtTestResultDetail -Result "Found $($items.Count) broad-principal gMSA password-retrieval authorization candidate(s). This proves authorization evidence only; no managed password was requested or used.`n`n$table";return $false}
    if($incomplete.Count -gt 0){Add-MtTestResultDetail -Result "No broad trustee was identified, but authorization evidence was incomplete for $($incomplete.Count) gMSA object(s)." -Investigate;return $null}
    Add-MtTestResultDetail -Result 'No broad-principal gMSA password-retrieval authorization was detected in complete collected evidence.'
    return $true
}