This test checks if all owners of app registrations have Multi-Factor Authentication (MFA) registered. App registration owners without MFA pose a significant security risk as credential stuffing attacks can lead to privileged access and potential privilege escalation or data loss.

## Why This Matters

App registration owners have powerful permissions that attackers actively target:

- **Credential Stuffing Risk**: Without MFA, compromised passwords from data breaches provide immediate access
- **Privileged App Access**: Owners can modify app permissions, certificates, and redirect URIs
- **Privilege Escalation**: Compromised owners can grant themselves or malicious apps excessive permissions
- **Lateral Movement**: Access to one app registration can be leveraged to compromise other resources

## Attack Scenario

1. **Initial Compromise**: Attacker uses leaked credentials to access owner account (no MFA protection)
2. **App Manipulation**: Attacker modifies app registration to add malicious redirect URIs, certificates or secrets
3. **Broader Access**: Compromised app is used to access sensitive data across the organization or to escalate privileges

#### Remediation action
Register MFA for all app registration owners listed. Use conditional access policies to enforce MFA for all application owners.

<!--- Results --->
%TestResult%