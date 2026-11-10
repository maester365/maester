function Test-MtAdDnsUnresolvedTrusteeAuthorization {
    [MaesterTest(Id='AD-DNS-21',Title='Unresolved trustees with DNS zone write authorization should be investigated',Product='ad',Feature='dns',Area='access-control',ResourceType='DnsZone',Severity='Info',Mitre='None',Service='ActiveDirectory',Permission=('ActiveDirectory:Ldap:dnsZone.ntSecurityDescriptor:ReadControl','ActiveDirectory:Ldap:Schema/classSchema.schemaIDGUID:ReadProperty'),Platform='Windows',Author='rolling-code')]
    [CmdletBinding()][OutputType([bool])]param()
    $state=Get-MtADDomainState -Categories @('DnsAuthorization')
    if($null -eq $state){Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory;return $null}
    if($null -eq $state.DnsAuthorization){Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'DNS authorization evidence is unavailable.';return $null}
    $items=@($state.DnsAuthorization.UnresolvedTrusteeAces)
    $result="| Zone | SID | Rights |`n| --- | --- | --- |`n"
    foreach($item in $items){$result+="| $($item.ZoneName) | $($item.TrusteeSid) | $($item.MatchedWriteRights -join ', ') |`n"}
    Add-MtTestResultDetail -Result "Found $($items.Count) unresolved trustee DNS write authorization candidate(s).`n`n$result" -Investigate
    return $true
}