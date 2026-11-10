function Test-MtAdGmsaBroadPasswordRetrievalAuthorization {
    [MaesterTest(Id='AD-MSA-02',Title='Broad principals should not be authorized to retrieve gMSA managed passwords',Product='ad',Feature='account-security',Area='privileged-access',ResourceType='Computer',Severity='High',UserImpact='Low',ImplementationCost='Medium',Mitre=('T1555'),Service='ActiveDirectory',Permission=('ActiveDirectory:Ldap:msDS-GroupManagedServiceAccount.msDS-GroupMSAMembership:ReadProperty'),Platform='Windows',Author='rolling-code')]
    [CmdletBinding()][OutputType([bool])]param()
    $state=Get-MtADDomainState -Categories ServiceAccounts
    if($null -eq $state){Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory;return $null}
    $items=@($state.ServiceAccounts|ForEach-Object{$gmsa=$_;@($gmsa.BroadPasswordRetrievalTrustees)|ForEach-Object{[pscustomobject]@{Account=$gmsa.SamAccountName;Trustee=$_.Name;Sid=$_.Sid;Source=$_.AuthorizationSource}}})
    $table="| gMSA | Trustee | SID | Source |`n| --- | --- | --- | --- |`n";foreach($i in $items){$table+="| $($i.Account) | $($i.Trustee) | $($i.Sid) | $($i.Source) |`n"}
    Add-MtTestResultDetail -Result "Found $($items.Count) broad-principal gMSA password-retrieval authorization candidate(s). This proves authorization evidence only; no managed password was requested or used.`n`n$table"
    return ($items.Count -eq 0)
}