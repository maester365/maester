function Test-MtCheckMT1228 {
<#
.SYNOPSIS
Apps scoped with Exchange RBAC for Applications should not hold the same or a broader permission tenant-wide in Microsoft Entra ID.

.DESCRIPTION
Exchange RBAC for Applications can limit an app to a set of mailboxes, but grants in Exchange and Microsoft Entra ID
add together. If the app also holds the same Microsoft Graph permission tenant-wide in Entra ID, or a broader one that
includes it, the Exchange scope has no effect. Runs the shared check Test-MtExoAppRbacOverlap.
#>
[MaesterTest(
Id = 'MT.1228',
Title = 'Apps scoped with Exchange RBAC for Applications should not hold the same or a broader permission tenant-wide in Microsoft Entra ID.',
Product = 'entra',
RelatedProduct = 'exchange',
Feature = 'app-consent',
Area = 'applications',
ResourceType = 'ServicePrincipal',
Severity = 'Medium',
UserImpact = 'Low',
ImplementationCost = 'Medium',
Mitre = 'T1114.002',
Control = ('nist-800-53-r5:AC-6', 'nist-800-53-r5:AC-3'),
Service = ('Graph', 'ExchangeOnline'),
Author = 'Dfrank77'
)]
[CmdletBinding()]
[OutputType([bool])]
param()

return Test-MtExoAppRbacOverlap
}
