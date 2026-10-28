# Service registry (Maester 3.0 design, section 6). [MaesterTest(Service = ...)] values are validated
# against these names. Every service a test lists must be connected for the test to run.
#
#   Probe            Test-MtConnection -Service value used to detect the connection
#   OptIn            tests are NotRun (OptInServiceNotConnected) instead of Skipped when not connected
#   RunspaceBound    the session exists only in the runspace that connected; such tests stay on the main lane
#   LegacySkipCode   the Add-MtTestResultDetail -SkippedBecause code written to ResultDetail, as 2.x guards did
#   Aliases          other names accepted in the attribute
#   PermissionKinds  the kinds of grant a [MaesterTest(Permission = '<Service>:<Kind>:<Name>')] value may name
#                    for this service, each with an example name and what it is (test attribute design, section 2.4)
@{
    SchemaVersion = '1.1'
    Services      = @{
        Graph              = @{
            Probe = 'Graph'; OptIn = $false; RunspaceBound = $false; LegacySkipCode = 'NotConnectedGraph'
            PermissionKinds = @(
                @{ Kind = 'Scope'; Example = 'Policy.Read.All'; Description = 'A Microsoft Graph permission that works as a delegated or an application permission.' }
                @{ Kind = 'DelegatedScope'; Example = 'User.Read'; Description = 'A Microsoft Graph permission the test can use only as a delegated permission, with a user signed in.' }
                @{ Kind = 'ApplicationScope'; Example = 'User.Read.All'; Description = 'A Microsoft Graph permission the test can use only as an application permission.' }
                @{ Kind = 'Role'; Example = 'Global Reader'; Description = 'A Microsoft Entra role, by its display name.' }
            )
        }
        Azure              = @{
            Probe = 'Azure'; OptIn = $false; RunspaceBound = $false; LegacySkipCode = 'NotConnectedAzure'
            PermissionKinds = @(
                @{ Kind = 'Role'; Example = 'Reader'; Description = 'An Azure role (Azure RBAC), by its name. The scope it is assigned at is chosen when Maester is set up.' }
                @{ Kind = 'Action'; Example = 'Microsoft.Authorization/policyAssignments/read'; Description = 'An Azure resource provider operation.' }
            )
        }
        ExchangeOnline     = @{
            Probe = 'ExchangeOnline'; OptIn = $false; RunspaceBound = $true; LegacySkipCode = 'NotConnectedExchange'; Aliases = @('Exchange')
            PermissionKinds = @(
                @{ Kind = 'Role'; Example = 'View-Only Configuration'; Description = 'An Exchange Online management role or role group, or a Microsoft Entra role that grants one.' }
                @{ Kind = 'Cmdlet'; Example = 'Get-OrganizationConfig'; Description = 'An Exchange Online PowerShell cmdlet the test runs.' }
            )
        }
        SecurityCompliance = @{
            Probe = 'SecurityCompliance'; OptIn = $false; RunspaceBound = $true; LegacySkipCode = 'NotConnectedSecurityCompliance'; Aliases = @('EOP')
            PermissionKinds = @(
                @{ Kind = 'Role'; Example = 'View-Only DLP Compliance Management'; Description = 'A Microsoft Purview role or role group, or a Microsoft Entra role that grants one.' }
                @{ Kind = 'Cmdlet'; Example = 'Get-DlpCompliancePolicy'; Description = 'A Security & Compliance PowerShell cmdlet the test runs.' }
            )
        }
        SharePointOnline   = @{
            Probe = 'SharePointOnline'; OptIn = $false; RunspaceBound = $true; LegacySkipCode = 'NotConnectedSharePoint'; Aliases = @('SharePoint')
            PermissionKinds = @(
                @{ Kind = 'Scope'; Example = 'Sites.FullControl.All'; Description = 'A SharePoint permission (the SharePoint API, not Microsoft Graph).' }
                @{ Kind = 'Role'; Example = 'SharePoint Administrator'; Description = 'A Microsoft Entra role, by its display name.' }
            )
        }
        Teams              = @{
            Probe = 'Teams'; OptIn = $false; RunspaceBound = $true; LegacySkipCode = 'NotConnectedTeams'
            PermissionKinds = @(
                @{ Kind = 'Role'; Example = 'Teams Administrator'; Description = 'A Microsoft Entra role, by its display name.' }
                @{ Kind = 'Cmdlet'; Example = 'Get-CsTeamsMeetingPolicy'; Description = 'A Microsoft Teams PowerShell cmdlet the test runs.' }
            )
        }
        # Dataverse uses the Graph sign-in to obtain its token.
        Dataverse          = @{
            Probe = 'Graph'; OptIn = $false; RunspaceBound = $false; LegacySkipCode = 'NotConnectedGraph'
            PermissionKinds = @(
                @{ Kind = 'Role'; Example = 'System Administrator'; Description = 'A Dataverse security role of the environment.' }
            )
        }
        AzureDevOps        = @{
            Probe = 'AzureDevOps'; OptIn = $false; RunspaceBound = $true; LegacySkipCode = 'NotConnectedAzureDevOps'
            PermissionKinds = @(
                @{ Kind = 'Scope'; Example = 'vso.project'; Description = 'An Azure DevOps OAuth or personal access token scope.' }
                @{ Kind = 'Role'; Example = 'Project Collection Administrators'; Description = 'An Azure DevOps security group or access level.' }
            )
        }
        GitHub             = @{
            Probe = 'GitHub'; OptIn = $false; RunspaceBound = $false; LegacySkipCode = 'NotConnectedGitHub'
            PermissionKinds = @(
                @{ Kind = 'Permission'; Example = 'administration:read'; Description = 'A GitHub App or fine-grained token permission, written <permission>:<read|write>.' }
                @{ Kind = 'Scope'; Example = 'read:org'; Description = 'A classic personal access token scope.' }
                @{ Kind = 'Role'; Example = 'Organization owner'; Description = 'A GitHub organization or enterprise role.' }
            )
        }
        ActiveDirectory    = @{
            Probe = 'ActiveDirectory'; OptIn = $true; RunspaceBound = $true; LegacySkipCode = 'NotConnectedActiveDirectory'; Aliases = @('AD')
            PermissionKinds = @(
                @{ Kind = 'Ldap'; Example = 'user:ReadProperty'; Description = 'An LDAP access right on an object class, written [<partition>/]<objectClass>[.<attribute>]:<right>. The partition is Configuration or Schema; without one it is the domain.' }
                @{ Kind = 'Cim'; Example = 'root\MicrosoftDNS:MicrosoftDNS_Zone:Read'; Description = 'Remote CIM (WMI) access, written <namespace>:<class>:<right>.' }
                @{ Kind = 'File'; Example = 'SYSVOL:Read'; Description = 'Access to a share on the domain controllers, written <share>:<right>.' }
                @{ Kind = 'Remoting'; Example = 'Microsoft.PowerShell'; Description = 'A PowerShell remoting endpoint on the domain controllers.' }
                @{ Kind = 'Group'; Example = 'Remote Management Users'; Description = 'Membership of a built-in or delegated group.' }
            )
        }
    }
}
