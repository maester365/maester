# Taxonomy registry for the classification attributes of [MaesterTest]:
# Product, RelatedProduct, Feature, Area and ResourceType.
#
# A test shipped with Maester must use keys from this file. A custom test may use any value.
# Keys are stable and never shown to users on their own; Name is the display text. Renaming a
# product or feature means changing Name only.
#
#   Products       in the order of the console lanes and the report
#     Key          value written in the attribute, lowercase kebab-case
#     Name         display name
#     Aliases      other spellings accepted in the attribute and resolved to Key
#     Features     the parts of the product a test can be about; a Feature key is scoped to its product
#   Areas          cross-product security themes; a test has exactly one
#   ResourceTypes  what a failing result points at; Tenant means a tenant-wide setting
#
# The rules for choosing a value are in website/docs/writing-tests/attribute-rubric.md.
# A new key is a deliberate addition: add it here in the same pull request as the first test that uses it.
@{
    SchemaVersion = '1.0'

    Products      = @(
        @{
            Key      = 'entra'
            Name     = 'Entra ID'
            Aliases  = @('Entra ID', 'Entra', 'Microsoft Entra')
            Features = @(
                @{ Key = 'conditional-access'; Name = 'Conditional Access' }
                @{ Key = 'authentication-methods'; Name = 'Authentication methods' }
                @{ Key = 'password-protection'; Name = 'Password protection' }
                @{ Key = 'identity-protection'; Name = 'Identity Protection' }
                @{ Key = 'privileged-identity-management'; Name = 'Privileged Identity Management' }
                @{ Key = 'roles'; Name = 'Roles and administrators' }
                @{ Key = 'applications'; Name = 'Applications' }
                @{ Key = 'app-consent'; Name = 'App consent and permissions' }
                @{ Key = 'external-identities'; Name = 'External identities' }
                @{ Key = 'identity-governance'; Name = 'Identity Governance' }
                @{ Key = 'user-settings'; Name = 'User and directory settings' }
                @{ Key = 'groups'; Name = 'Groups' }
                @{ Key = 'devices'; Name = 'Device identity' }
                @{ Key = 'hybrid-identity'; Name = 'Hybrid identity' }
                @{ Key = 'global-secure-access'; Name = 'Global Secure Access' }
                @{ Key = 'agent-identities'; Name = 'Agent identities' }
                @{ Key = 'monitoring'; Name = 'Logs and monitoring' }
                @{ Key = 'recommendations'; Name = 'Entra recommendations' }
            )
        }
        @{
            Key      = 'exchange'
            Name     = 'Exchange Online'
            Aliases  = @('Exchange Online', 'Exchange', 'EXO')
            Features = @(
                @{ Key = 'mail-flow'; Name = 'Mail flow' }
                @{ Key = 'email-authentication'; Name = 'Email authentication' }
                @{ Key = 'client-access'; Name = 'Client access' }
                @{ Key = 'sharing'; Name = 'Calendar and contact sharing' }
                @{ Key = 'mailbox-auditing'; Name = 'Mailbox auditing' }
                @{ Key = 'anti-malware'; Name = 'Anti-malware' }
                @{ Key = 'anti-phishing'; Name = 'Anti-phishing' }
                @{ Key = 'anti-spam'; Name = 'Anti-spam' }
                @{ Key = 'safe-links'; Name = 'Safe Links' }
                @{ Key = 'data-loss-prevention'; Name = 'Data loss prevention' }
                @{ Key = 'alerts'; Name = 'Alert policies' }
                @{ Key = 'audit-logging'; Name = 'Audit logging' }
                @{ Key = 'outlook'; Name = 'Outlook' }
                @{ Key = 'mailboxes'; Name = 'Mailboxes' }
            )
        }
        @{
            Key      = 'defender'
            Name     = 'Defender'
            Aliases  = @('Defender', 'Microsoft Defender', 'Defender XDR')
            Features = @(
                @{ Key = 'anti-spam'; Name = 'Anti-spam' }
                @{ Key = 'anti-phishing'; Name = 'Anti-phishing' }
                @{ Key = 'anti-malware'; Name = 'Anti-malware' }
                @{ Key = 'safe-links'; Name = 'Safe Links' }
                @{ Key = 'safe-attachments'; Name = 'Safe Attachments' }
                @{ Key = 'zero-hour-auto-purge'; Name = 'Zero-hour auto purge' }
                @{ Key = 'quarantine'; Name = 'Quarantine' }
                @{ Key = 'email-authentication'; Name = 'Email authentication' }
                @{ Key = 'mail-flow'; Name = 'Mail flow' }
                @{ Key = 'tenant-settings'; Name = 'Tenant settings' }
                @{ Key = 'endpoint-antivirus'; Name = 'Endpoint antivirus' }
                @{ Key = 'exposure-management'; Name = 'Exposure Management' }
                @{ Key = 'defender-for-identity'; Name = 'Defender for Identity' }
            )
        }
        @{
            Key      = 'intune'
            Name     = 'Intune'
            Aliases  = @('Intune', 'Microsoft Intune')
            Features = @(
                @{ Key = 'device-compliance'; Name = 'Device compliance' }
                @{ Key = 'device-enrollment'; Name = 'Device enrollment' }
                @{ Key = 'device-configuration'; Name = 'Device configuration' }
                @{ Key = 'endpoint-security'; Name = 'Endpoint security' }
                @{ Key = 'tenant-administration'; Name = 'Tenant administration' }
            )
        }
        @{
            Key      = 'purview'
            Name     = 'Purview'
            Aliases  = @('Purview', 'Microsoft Purview')
            Features = @(
                @{ Key = 'audit'; Name = 'Audit' }
                @{ Key = 'information-protection'; Name = 'Information protection' }
                @{ Key = 'data-loss-prevention'; Name = 'Data loss prevention' }
                @{ Key = 'data-lifecycle-management'; Name = 'Data lifecycle management' }
                @{ Key = 'insider-risk-management'; Name = 'Insider risk management' }
            )
        }
        @{
            Key      = 'sharepoint'
            Name     = 'SharePoint'
            Aliases  = @('SharePoint', 'SharePoint Online', 'SharePoint and OneDrive')
            Features = @(
                @{ Key = 'external-sharing'; Name = 'External sharing' }
                @{ Key = 'sharing-links'; Name = 'Sharing links' }
                @{ Key = 'access-control'; Name = 'Access control' }
            )
        }
        @{
            Key      = 'teams'
            Name     = 'Teams'
            Aliases  = @('Teams', 'Microsoft Teams')
            Features = @(
                @{ Key = 'meetings'; Name = 'Meetings' }
                @{ Key = 'external-access'; Name = 'External access' }
                @{ Key = 'messaging'; Name = 'Messaging' }
                @{ Key = 'apps'; Name = 'Apps' }
                @{ Key = 'file-sharing'; Name = 'File sharing' }
            )
        }
        @{
            Key      = 'microsoft-365'
            Name     = 'Microsoft 365'
            Aliases  = @('Microsoft 365', 'M365')
            Features = @(
                @{ Key = 'administrative-accounts'; Name = 'Administrative accounts' }
                @{ Key = 'organization-settings'; Name = 'Organization settings' }
                @{ Key = 'teams-and-groups'; Name = 'Teams and groups' }
                @{ Key = 'configuration-drift'; Name = 'Configuration drift' }
            )
        }
        @{
            Key      = 'azure'
            Name     = 'Azure'
            Aliases  = @('Azure', 'Microsoft Azure')
            Features = @(
                @{ Key = 'access-management'; Name = 'Access management' }
                @{ Key = 'management-groups'; Name = 'Management groups' }
                @{ Key = 'backup'; Name = 'Backup' }
            )
        }
        @{
            Key      = 'azure-devops'
            Name     = 'Azure DevOps'
            Aliases  = @('Azure DevOps', 'AzDO')
            Features = @(
                @{ Key = 'organization-policies'; Name = 'Organization policies' }
                @{ Key = 'security-policies'; Name = 'Security policies' }
                @{ Key = 'pipelines'; Name = 'Pipelines' }
                @{ Key = 'repositories'; Name = 'Repositories' }
                @{ Key = 'users-and-access'; Name = 'Users and access' }
                @{ Key = 'auditing'; Name = 'Auditing' }
                @{ Key = 'resource-usage'; Name = 'Resource usage and limits' }
            )
        }
        @{
            Key      = 'github'
            Name     = 'GitHub'
            Aliases  = @('GitHub')
            Features = @(
                @{ Key = 'organization-settings'; Name = 'Organization settings' }
                @{ Key = 'branch-protection'; Name = 'Branch protection' }
                @{ Key = 'enterprise-settings'; Name = 'Enterprise settings' }
            )
        }
        @{
            Key      = 'ad'
            Name     = 'Active Directory'
            Aliases  = @('Active Directory', 'AD', 'ADDS')
            Features = @(
                @{ Key = 'users'; Name = 'Users' }
                @{ Key = 'computers'; Name = 'Computers' }
                @{ Key = 'groups'; Name = 'Groups' }
                @{ Key = 'organizational-units'; Name = 'Organizational units' }
                @{ Key = 'account-security'; Name = 'Account security' }
                @{ Key = 'password-policy'; Name = 'Password policy' }
                @{ Key = 'domain-controllers'; Name = 'Domain controllers' }
                @{ Key = 'domain-and-forest'; Name = 'Domain and forest' }
                @{ Key = 'directory-configuration'; Name = 'Directory configuration' }
                @{ Key = 'dns'; Name = 'DNS' }
                @{ Key = 'group-policy'; Name = 'Group Policy' }
                @{ Key = 'permissions'; Name = 'Permissions and delegation' }
                @{ Key = 'service-principal-names'; Name = 'Service principal names' }
                @{ Key = 'sites-and-subnets'; Name = 'Sites and subnets' }
                @{ Key = 'replication'; Name = 'Replication' }
                @{ Key = 'trusts'; Name = 'Trusts' }
                @{ Key = 'schema'; Name = 'Schema' }
                @{ Key = 'certificate-services'; Name = 'Certificate Services' }
                @{ Key = 'printers'; Name = 'Printers' }
            )
        }
        @{
            Key      = 'copilot-studio'
            Name     = 'Copilot Studio'
            Aliases  = @('Copilot Studio')
            Features = @(
                @{ Key = 'agents'; Name = 'Agents' }
            )
        }
    )

    Areas         = @(
        @{ Key = 'authentication'; Name = 'Authentication'; Description = 'How an identity proves who it is: MFA, authentication methods, passwords, legacy protocols, Kerberos and NTLM hardening, session and token lifetime.' }
        @{ Key = 'privileged-access'; Name = 'Privileged access'; Description = 'Administrative roles and accounts: who holds them, just-in-time elevation, emergency access, admin tiering and delegated admin rights.' }
        @{ Key = 'access-control'; Name = 'Access control'; Description = 'Who may reach which resource under which conditions: device, location and risk conditions, permissions on objects, user defaults.' }
        @{ Key = 'applications'; Name = 'Applications and workload identities'; Description = 'App registrations, service principals and their credentials, consent and API permissions, OAuth apps, add-ins and connectors.' }
        @{ Key = 'external-access'; Name = 'External access and sharing'; Description = 'Guests, cross-tenant access, federation and trusts, external sharing of files and external communication.' }
        @{ Key = 'devices'; Name = 'Devices and endpoints'; Description = 'Device compliance, enrollment and configuration, endpoint protection and device identity.' }
        @{ Key = 'email-protection'; Name = 'Email and collaboration protection'; Description = 'Anti-phishing, anti-spam and anti-malware, Safe Links and Safe Attachments, SPF, DKIM and DMARC, mail flow rules, meeting and messaging protections.' }
        @{ Key = 'data-protection'; Name = 'Data protection'; Description = 'Data loss prevention, sensitivity labels, encryption, retention and backup.' }
        @{ Key = 'logging-and-detection'; Name = 'Logging and detection'; Description = 'Audit logs, diagnostic settings, alert policies, sensors and the health of detection tooling.' }
        @{ Key = 'identity-lifecycle'; Name = 'Identity lifecycle and hygiene'; Description = 'Stale and dormant accounts, ownership, access reviews, entitlement management and group membership hygiene.' }
        @{ Key = 'infrastructure'; Name = 'Infrastructure hardening'; Description = 'The directory and platform itself: domain controllers, DNS, replication, sites, schema, Group Policy health, protocol hardening, subscriptions and tenant-wide platform settings.' }
        @{ Key = 'engineering-systems'; Name = 'Engineering systems'; Description = 'DevOps organizations, repositories, pipelines, build identities and the software supply chain.' }
        @{ Key = 'ai'; Name = 'AI and agents'; Description = 'AI agents and copilots: who can use and share them, how they authenticate and what data and tools they can reach.' }
    )

    ResourceTypes = @(
        @{ Key = 'Tenant'; Description = 'A tenant-, organization-, forest- or domain-wide setting. The result is about the environment, not a list of objects.' }
        @{ Key = 'User'; Description = 'User accounts, including guests and admin accounts.' }
        @{ Key = 'Group'; Description = 'Security, Microsoft 365 and distribution groups.' }
        @{ Key = 'Application'; Description = 'App registrations.' }
        @{ Key = 'ServicePrincipal'; Description = 'Enterprise applications, managed identities and other service principals.' }
        @{ Key = 'Agent'; Description = 'AI agents and agent identities.' }
        @{ Key = 'Device'; Description = 'Managed or registered devices.' }
        @{ Key = 'DirectoryRole'; Description = 'Directory roles and role assignments.' }
        @{ Key = 'ConditionalAccessPolicy'; Description = 'Conditional Access policies.' }
        @{ Key = 'Policy'; Description = 'Any other policy object, such as an anti-phishing, compliance, DLP or meeting policy.' }
        @{ Key = 'MailFlowRule'; Description = 'Exchange mail flow (transport) rules.' }
        @{ Key = 'Connector'; Description = 'Connectors, tokens and certificates that link the tenant to another service, and mail flow connectors.' }
        @{ Key = 'AccessPackage'; Description = 'Entitlement management access packages, catalogs and assignment policies.' }
        @{ Key = 'Mailbox'; Description = 'Mailboxes.' }
        @{ Key = 'Domain'; Description = 'Email and DNS domains registered in the tenant.' }
        @{ Key = 'AzureResource'; Description = 'Azure resources such as vaults, storage accounts and virtual machines.' }
        @{ Key = 'Project'; Description = 'Azure DevOps projects.' }
        @{ Key = 'Repository'; Description = 'Source repositories.' }
        @{ Key = 'Computer'; Description = 'Active Directory computer accounts other than domain controllers.' }
        @{ Key = 'DomainController'; Description = 'Active Directory domain controllers.' }
        @{ Key = 'GroupPolicy'; Description = 'Group Policy objects and links.' }
        @{ Key = 'OrganizationalUnit'; Description = 'Active Directory organizational units and containers.' }
        @{ Key = 'DnsZone'; Description = 'DNS zones and records.' }
        @{ Key = 'AdSite'; Description = 'Active Directory sites, subnets and site links.' }
        @{ Key = 'Trust'; Description = 'Active Directory domain and forest trusts.' }
        @{ Key = 'Permission'; Description = 'Access control entries and delegations on directory objects.' }
        @{ Key = 'CertificateAuthority'; Description = 'Certification authorities, certificate templates and published CA certificates.' }
    )

    # MITRE ATT&CK release the Mitre attribute is validated against (powershell/assets/MaesterAttackTechniques.json).
    Attack        = @{
        Version = '19.2'
        File    = 'MaesterAttackTechniques.json'
    }
}
