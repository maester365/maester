# The measure registry of the defender's path (docs/proposals/defenders-path.md, section 11).
#
# A measure is a figure the engine reads from Graph for a step that is a state of the tenant, such as the share of
# devices that sign in and are compliant. A step names a measure in the step catalogue
# (powershell/assets/steps/<product>.json) as "Measure": { "Key": "<key>", "MinimumShare": <1 to 100> }, and the step
# is done when the figure meets its threshold. A measure is not a test: it has no ID, no result row and no place in
# pass rates.
#
# Keys of each entry:
#   Key         lowercase kebab-case, the name a step's Measure uses
#   Function    the internal reader in powershell/internal/services/<service>/. It reads through the Graph cache and
#               returns Count (objects that meet the bar), Total and Objects (those that fall short, as Type, Id and
#               DisplayName)
#   Title       one line, shown with the figure, for example 'Devices that sign in are compliant'
#   Unit        what is counted, plural, for example 'devices'
#   Caveat      one line of 200 characters or less, shown with the figure, on what it can't see or leaves out
#               (optional)
#   Service     services that must all be connected, as in a test's Service attribute
#   License     service plans, any one of which is enough, as in a test's License attribute (optional)
#   Permission  permissions the reader needs, as in a test's Permission attribute (optional)
@{
    Measures = @(
        @{
            # Step intune.devices-compliant. isCompliant is set by Intune, also for the devices of a compliance partner,
            # which needs Intune licences as well, so a tenant without Intune has no figure to read.
            Key        = 'devices-compliant'
            Function   = 'Get-MtDeviceComplianceShare'
            Title      = 'Devices that sign in are compliant'
            Unit       = 'devices'
            Caveat     = "Devices that aren't registered or joined in Microsoft Entra ID can't be counted. A compliant-device policy blocks them too."
            Service    = 'Graph'
            License    = 'INTUNE_A'
            Permission = 'Graph:Scope:Device.Read.All | Graph:Scope:Directory.Read.All'
        }
        @{
            # Step entra.mfa-registered. isMfaCapable, not isMfaRegistered: the method must also be one the
            # authentication methods policy allows, or the user still can't complete MFA. The registration report needs
            # Microsoft Entra ID P1 and AuditLog.Read.All.
            Key        = 'mfa-capable'
            Function   = 'Get-MtMfaCapableShare'
            Title      = 'Enabled member users can complete MFA'
            Unit       = 'users'
            Caveat     = 'Counts only methods the authentication methods policy allows. Guests, disabled users, emergency access and directory sync accounts are left out.'
            Service    = 'Graph'
            License    = 'AAD_PREMIUM'
            Permission = ('Graph:Scope:AuditLog.Read.All', 'Graph:Scope:Directory.Read.All')
        }
    )
}
