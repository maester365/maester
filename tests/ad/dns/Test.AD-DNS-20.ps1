function Test-MtAdDnsBroadPrincipalAuthorization {
    [MaesterTest(Id='AD-DNS-20',Title='Broad principals should not have applicable DNS zone write authorization',Product='ad',Feature='dns',Area='access-control',ResourceType='DnsZone',Severity='Medium',UserImpact='Low',ImplementationCost='Medium',Mitre=('T1098'),Service='ActiveDirectory',Permission=('ActiveDirectory:Ldap:dnsZone.ntSecurityDescriptor:ReadControl','ActiveDirectory:Ldap:Schema/classSchema.schemaIDGUID:ReadProperty'),Platform='Windows',Author='rolling-code')]
    [CmdletBinding()][OutputType([bool])]param()
    $state=Get-MtADDomainState -Categories @('DnsAuthorization')
    if($null -eq $state){ Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory; return $null }
    if($null -eq $state.DnsAuthorization){ Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'DNS authorization evidence is unavailable.'; return $null }
    $items=@($state.DnsAuthorization.BroadPrincipalAces)
    $result="| Zone | Trustee | Rights | Explicit |`n| --- | --- | --- | --- |`n"
    foreach($item in $items){$result+="| $($item.ZoneName) | $($item.TrusteeName) | $($item.MatchedWriteRights -join ', ') | $(-not $item.IsInherited) |`n"}
    if($items.Count){Add-MtTestResultDetail -Result "Found $($items.Count) applicable broad-principal DNS zone write authorization candidate(s). This proves authorization, not successful record creation or downstream impact.`n`n$result"}
    else{Add-MtTestResultDetail -Result 'No applicable broad-principal DNS zone write authorization was detected in the readable zone ACLs.'}
    return ($items.Count -eq 0)
}