Microsoft Entra Connect uses a connector identity to synchronize an on-premises directory with Microsoft Entra ID.
Legacy installations can use a user-based directory synchronization account. These accounts should be excluded from
Conditional Access policies scoped to all cloud apps and all users, and their access should be restricted to trusted
networks.

New installations of Microsoft Entra Connect 2.5.76.0 or later use application-based authentication by default, with a
service principal and certificate instead of a user account and password. Existing installations do not switch to
application-based authentication automatically.

This test evaluates user principals assigned to the directory synchronization roles. It passes automatically when no
user principals remain, because Conditional Access user exclusions do not apply to service principals; the test does not
need to be muted. To verify the authentication method currently used, run Get-ADSyncEntraConnectorCredential on every
Microsoft Entra Connect server and confirm that ConnectorIdentityType is Application. After verifying the migration,
remove the legacy directory synchronization account or remove its directory synchronization role assignment.

#### Remediation action

Review the configuration described above.

<!--- Results --->
%TestResult%
