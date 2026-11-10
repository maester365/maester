function Test-MtAdDnsBroadPrincipalAuthorization {
    [MaesterTest(Id='AD-DNS-20',Title='Broad principals should not have applicable DNS zone write authorization',Product='ad',Feature='dns',Area='access-control',ResourceType='DnsZone',Severity='Medium',UserImpact='Low',ImplementationCost='Medium',Mitre=('T1557'),Service='ActiveDirectory',Permission=('ActiveDirectory:Ldap:dnsZone.ntSecurityDescriptor:ReadControl','ActiveDirectory:Ldap:Schema/classSchema.schemaIDGUID:ReadProperty'),Platform='Windows',Author='rolling-code')]
    [CmdletBinding()][OutputType([bool])]param()
    $state=Get-MtADDomainState -Categories @('DnsAuthorization')
    if($null -eq $state){ Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory; return $null }
    if($null -eq $state.DnsAuthorization){ Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'DNS authorization evidence is unavailable.'; return $null }
    $coverage=$state.DnsAuthorization.Coverage
    if(@($state.DnsAuthorization.CollectionErrors).Count -gt 0 -or $null -eq $coverage -or $coverage.ZoneCount -eq 0 -or $coverage.ReadableZoneCount -lt $coverage.ZoneCount -or -not $state.DnsAuthorization.DnsNodeSchemaGuid){
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'DNS zone ACL collection was incomplete; review collection errors, zone coverage, and schema GUID resolution.'
        return $null
    }    $items=@($state.DnsAuthorization.BroadPrincipalAces)
    $result="| Zone | Trustee | Rights | Explicit |`n| --- | --- | --- | --- |`n"
    foreach($item in $items){$result+="| $($item.ZoneName) | $($item.TrusteeName) | $($item.MatchedWriteRights -join ', ') | $(-not $item.IsInherited) |`n"}
    if($items.Count){Add-MtTestResultDetail -Result "Found $($items.Count) applicable broad-principal DNS zone write authorization candidate(s). This proves authorization, not successful record creation or downstream impact.`n`n$result"}
    else{Add-MtTestResultDetail -Result 'No applicable broad-principal DNS zone write authorization was detected in the readable zone ACLs.'}
    return ($items.Count -eq 0)
}