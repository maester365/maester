# Feature icons

Icons shown beside a feature's name in the report (product pages, the test list's Feature filter and a test's
Feature fact). `report/src/lib/featureIcons.ts` says which file stands for which feature.

- Source: [DanielBradley1/msicons](https://github.com/DanielBradley1/msicons) (msicons.com), commit `3d57443ed444`, taken on
  2026-11-02. Minified (whitespace and comments removed, coordinates rounded to one decimal, or to whole numbers in
  the 48-unit icons); shapes and colours unchanged.
- The icons are Microsoft's, under the same terms as `../products/README.md`: used unchanged, beside the name
  of the feature they stand for. Several are generic icons (mail, key, globe) chosen for a feature that has no icon of its own.

| File | msicons path | Features |
| --- | --- | --- |
| activity-log.svg | monitor/00007-icon-service-Activity-Log.svg | exchange/mailbox-auditing, exchange/audit-logging, purview/audit, azure-devops/auditing |
| advisor.svg | management-governance/00003-icon-service-Advisor.svg | entra/recommendations |
| alerts.svg | management-governance/00002-icon-service-Alerts.svg | exchange/alerts |
| app-registrations.svg | identity/10232-icon-service-App-Registrations.svg | entra/app-consent |
| apps.svg | Microsoft/dark-blue-Apps.svg | teams/apps |
| arrow-download.svg | Microsoft/dark-blue-Arrow Download.svg | fabric/export-and-sharing |
| arrow-sync.svg | Microsoft/dark-blue-Arrow Sync.svg | ad/replication |
| azure-information-protection.svg | identity/10229-icon-service-Azure-Information-Protection.svg | purview/information-protection, fabric/information-protection |
| book-contacts.svg | Microsoft/dark-blue-Book Contacts.svg | exchange/mailboxes |
| bot.svg | Microsoft/dark-blue-Bot.svg | entra/agent-identities, copilot-studio/agents |
| building.svg | Microsoft/dark-blue-Building.svg | microsoft-365/organization-settings, github/organization-settings |
| builds.svg | general/10785-icon-service-Builds.svg | azure-devops/pipelines |
| calendar-month.svg | Microsoft/dark-blue-Calendar Month.svg | exchange/sharing |
| certificate.svg | Microsoft/dark-blue-Certificate.svg | exchange/email-authentication, defender/email-authentication, ad/certificate-services |
| change-analysis.svg | monitor/00563-icon-service-Change-Analysis.svg | microsoft-365/configuration-drift |
| chat.svg | Microsoft/dark-blue-Chat.svg | teams/messaging |
| clock-alarm.svg | Microsoft/dark-blue-Clock Alarm.svg | defender/zero-hour-auto-purge |
| code.svg | Microsoft/dark-blue-Code.svg | fabric/developer-settings |
| conditional-access.svg | security/10233-icon-service-Conditional-Access.svg | entra/conditional-access |
| desktop-tower.svg | Microsoft/dark-blue-Desktop Tower.svg | ad/computers |
| device-compliance.svg | intune/10333-icon-service-Device-Compliance.svg | intune/device-compliance |
| device-configuration.svg | intune/10338-icon-service-Device-Configuration.svg | intune/device-configuration |
| device-enrollment.svg | intune/10337-icon-service-Device-Enrollment.svg | intune/device-enrollment |
| device-security-windows.svg | intune/00399-icon-service-Device-Security-Windows.svg | defender/endpoint-antivirus |
| devices.svg | intune/10332-icon-service-Devices.svg | entra/devices |
| document-key.svg | Microsoft/dark-blue-Document Key.svg | ad/service-principal-names |
| document-lock.svg | Microsoft/dark-blue-Document Lock.svg | exchange/data-loss-prevention, purview/data-loss-prevention |
| enterprise-applications.svg | identity/10225-icon-service-Enterprise-Applications.svg | entra/applications |
| entra-connect.svg | identity/02854-icon-service-Entra-Connect.svg | entra/hybrid-identity |
| entra-domain-services.svg | identity/10222-icon-service-Entra-Domain-Services.svg | ad/domain-controllers |
| entra-global-secure-access.svg | identity/03309-icon-service-Entra-Global-Secure-Access.svg | entra/global-secure-access |
| entra-id-protection.svg | identity/10231-icon-service-Entra-ID-Protection.svg | entra/identity-protection |
| entra-identity-risky-users.svg | security/03342-icon-service-Entra-Identity-Risky-Users.svg | defender/defender-for-identity, purview/insider-risk-management |
| entra-identity-roles-and-administrators.svg | identity/10340-icon-service-Entra-Identity-Roles-and-Administrators.svg | entra/roles, microsoft-365/administrative-accounts |
| entra-privileged-identity-management.svg | identity/02251-icon-service-Entra-Privileged-Identity-Management.svg | entra/privileged-identity-management |
| exchange-access.svg | intune/10339-icon-service-Exchange-Access.svg | exchange/client-access |
| external-identities.svg | identity/03338-icon-service-External-Identities.svg | entra/external-identities |
| folder-people.svg | Microsoft/dark-blue-Folder People.svg | teams/file-sharing |
| globe.svg | Microsoft/dark-blue-Globe.svg | exchange/safe-links, defender/safe-links, ad/dns |
| groups.svg | identity/10223-icon-service-Groups.svg | entra/groups, microsoft-365/teams-and-groups, ad/groups |
| handshake.svg | Microsoft/dark-blue-Handshake.svg | ad/trusts |
| identity-governance.svg | identity/10235-icon-service-Identity-Governance.svg | entra/identity-governance |
| intune-app-protection.svg | intune/10344-icon-service-Intune-App-Protection.svg | intune/app-protection |
| key.svg | Microsoft/dark-blue-Key.svg | entra/password-protection, azure/access-management, ad/password-policy |
| layer-diagonal.svg | Microsoft/dark-blue-Layer Diagonal.svg | ad/schema |
| lock-closed.svg | Microsoft/dark-blue-Lock Closed.svg | defender/quarantine |
| lock-shield.svg | Microsoft/dark-blue-Lock Shield.svg | sharepoint/access-control, azure-devops/security-policies, ad/account-security |
| log-analytics-workspaces.svg | monitor/00009-icon-service-Log-Analytics-Workspaces.svg | entra/monitoring |
| mail.svg | Microsoft/dark-blue-Mail.svg | exchange/mail-flow, defender/mail-flow |
| mail-alert.svg | Microsoft/dark-blue-Mail Alert.svg | exchange/anti-phishing, defender/anti-phishing |
| mail-attach.svg | Microsoft/dark-blue-Mail Attach.svg | defender/safe-attachments |
| mail-error.svg | Microsoft/dark-blue-Mail Error.svg | exchange/anti-spam, defender/anti-spam |
| mail-read.svg | Microsoft/dark-blue-Mail Read.svg | exchange/outlook |
| management-groups.svg | general/10011-icon-service-Management-Groups.svg | azure/management-groups |
| map.svg | Microsoft/dark-blue-Map.svg | ad/sites-and-subnets |
| metrics.svg | monitor/00020-icon-service-Metrics.svg | azure-devops/resource-usage |
| microsoft-defender-easm.svg | security/03336-icon-service-Microsoft-Defender-EASM.svg | defender/exposure-management |
| multi-factor-authentication.svg | identity/03256-icon-service-Multi-Factor-Authentication.svg | entra/authentication-methods |
| organization.svg | Microsoft/dark-blue-Organization.svg | ad/organizational-units |
| organization-horizontal.svg | Microsoft/dark-blue-Organization Horizontal.svg | ad/domain-and-forest |
| people-community.svg | Microsoft/dark-blue-People Community.svg | teams/external-access |
| people-settings.svg | Microsoft/dark-blue-People Settings.svg | azure-devops/users-and-access, ad/permissions |
| policy.svg | management-governance/10316-icon-service-Policy.svg | azure-devops/organization-policies, ad/group-policy |
| recovery-services-vaults.svg | management-governance/00017-icon-service-Recovery-Services-Vaults.svg | azure/backup |
| resource-linked.svg | general/10831-icon-service-Resource-Linked.svg | sharepoint/sharing-links |
| security-baselines.svg | intune/10336-icon-service-Security-Baselines.svg | intune/endpoint-security |
| settings.svg | Microsoft/dark-blue-Settings.svg | defender/tenant-settings, fabric/tenant-settings |
| settings-cog-multiple.svg | Microsoft/dark-blue-Settings Cog Multiple.svg | ad/directory-configuration |
| share.svg | Microsoft/dark-blue-Share.svg | sharepoint/external-sharing |
| shield-error.svg | Microsoft/dark-blue-Shield Error.svg | exchange/anti-malware, defender/anti-malware |
| subscriptions.svg | general/10002-icon-service-Subscriptions.svg | azure/subscriptions |
| tenant-status.svg | intune/10342-icon-service-Tenant-Status.svg | intune/tenant-administration |
| tfs-vc-repository.svg | general/10843-icon-service-TFS-VC-Repository.svg | azure-devops/repositories |
| universal-print.svg | management-governance/00571-icon-service-Universal-Print.svg | ad/printers |
| user-settings.svg | identity/10433-icon-service-User-Settings.svg | entra/user-settings |
| users.svg | identity/10230-icon-service-Users.svg | ad/users |
| versions.svg | general/10845-icon-service-Versions.svg | purview/data-lifecycle-management |
| video.svg | Microsoft/dark-blue-Video.svg | teams/meetings |
