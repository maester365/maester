# Instructions

Based on the test information and the PowerShell code provided below, determine:
1. The **Severity** level (Critical, High, Medium, Low, Info).
2. The **RequiredPermissions** needed to run this test across different services.

Output your response ONLY as a valid JSON object with the following keys: `Severity`, `RequiredPermissions`. 
Do not include markdown fences or any other text.

Example output:
{
  "Severity": "High",
  "RequiredPermissions": {
    "Graph": ["Policy.Read.All", "User.Read.All"],
    "EntraRoles": ["Global Reader"],
    "ExchangeOnline": ["View-Only Configuration"],
    "Azure": ["Reader"]
  }
}

---
testInfo.json
%TEST_INFO_JSON%

---
PowerShell Code
%TEST_CODE%

---

## Permission Mapping Rules

Analyze the PowerShell code to identify which APIs and services are being called. 

### Microsoft Graph (Graph)
- If `Invoke-MtGraphRequest` is used, look at the `-RelativeUri`. 
  - `/policies/conditionalAccessPolicies` -> `Policy.Read.ConditionalAccess` or `Policy.Read.All`
  - `/users` -> `User.Read.All` or `Directory.Read.All`
  - `/applications` -> `Application.Read.All`
  - `/groups` -> `Group.Read.All`
  - `/directoryRoles` -> `RoleManagement.Read.Directory`
- Map other endpoints to their documented Graph permissions. 
- Always prefer `.Read` permissions over `.ReadWrite` unless the code is performing a POST/PATCH/DELETE.

### Entra ID Directory Roles (EntraRoles)
- If the test queries privileged data (like Global Admins, PIM assignments, or CA policies), specify at least one role that would grant this access, such as:
  - `Global Reader`
  - `Security Reader`
  - `Global Administrator` (only if highly privileged access is needed)

### Exchange Online (ExchangeOnline)
- If `Get-MtExo` or `Get-EXO*` cmdlets are used, identify the required Management Role:
  - `View-Only Configuration` (most common for reading settings)
  - `Security Reader`
  - `View-Only Recipients`

### Azure RBAC (Azure)
- If `Invoke-MtAzureRequest` or `Get-Az*` cmdlets are used, identify the required Azure role:
  - `Reader`
  - `Security Reader`
  - `Owner` / `Contributor` (if write access is needed)

---

## Severity Levels

Every Maester test includes a severity level. This severity level of Maester configuration is based on our self-calculated CVSS score for each specific vulnerability.

- Critical
- High
- Medium
- Low
- Info

For CVSS, Maester uses the following severity rating system:

| CVSS SCORE RANGE | SEVERITY IN TEST |
| --- | --- |
| 9.0 - 10.0 | Critical |
| 7.0 - 8.9 | High |
| 4.0 - 6.9 | Medium |
| 0.1 - 3.9 | Low |
| 0 | Info |

Below are a few examples of vulnerabilities which may result in a given severity level. Please keep in mind that this rating does not take into account details of your installation and are to be used as a guide only.

### Severity Level: Critical

Vulnerable configurations that score in the critical range usually have most of the following characteristics:

- Exploitation of the vulnerability likely results in unauthorized administrator level access of web applications, full access to application or user data, and/or root-level compromise of servers or infrastructure devices.
- Exploitation is usually straightforward, in the sense that the attacker does not need any special authentication credentials or knowledge about individual victims, and does not need to persuade a target user, for example via social engineering, into performing any special functions.

For critical vulnerabilities, is advised that you address the issue as soon as possible, unless you have other mitigating measures in place.

### Severity Level: High

Configuration vulnerabilities that score in the high range usually have some of the following characteristics:

- The configuration vulnerability is difficult to exploit.
- Exploitation could result in elevated privileges.
- Exploitation could result in a significant data loss or downtime.

### Severity Level: Medium

Configuration vulnerabilities that score in the medium range usually have some of the following characteristics:

- Vulnerabilities that require the attacker to manipulate individual victims via social engineering tactics.
- Denial of service vulnerabilities that are difficult to set up.
- Exploits that require an attacker to reside on the same local network as the victim.
- Vulnerabilities where exploitation provides only very limited access.
- Vulnerabilities that require user privileges for successful exploitation.

### Severity Level: Low

Vulnerabilities in the low range typically have very little impact on an organization's business. Exploitation of such vulnerabilities usually requires local or physical system access.

## Other IMPORTANT Considerations

- If a test is related to a vulnerability that can lead to privilege escalation, the severity should be at least High.
- If a test is related to privileged access (admin, privileged roles etc.), the severity should be High.
- If the test is related to a vulnerability that can lead to data loss or data exposure, the severity should be at least Medium.
- If a test is related to a setting that is a good practice but is not directly related to security or a vulnerability, the severity should be Low.
- If a test is related to a setting that is not security related or something the user cannot action on, the severity should be Info.
