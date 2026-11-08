Checks whether both Windows LAPS schema attributes are present: `msLAPS-Password` and `msLAPS-PasswordExpirationTime`. The verdict uses the top-level `WindowsLapsInstalled` state, derived from schema `lDAPDisplayName`; the result shows individual schema-name evidence.

Legacy LAPS (`ms-Mcs-AdmPwd`) uses a different schema and alone does not establish Windows LAPS readiness. Schema presence is not evidence that password rotation is configured or operating. This check reads schema *names* only, never password values; `msLAPS-Password` contains a cleartext secret and must not be collected.

#### Remediation action

1. [Extend the Active Directory schema for Windows LAPS](https://learn.microsoft.com/windows-server/identity/laps/laps-scenarios-windows-server-active-directory#update-the-windows-server-active-directory-schema).
2. Verify both schema attribute names are present, then separately deploy Windows LAPS policy, permissions, and password rotation to applicable devices.

<!--- Results --->
%TestResult%
