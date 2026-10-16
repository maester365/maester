---
title: Severity Levels
sidebar_position: 3
---

# Severity Levels for Maester Tests

## Severity Framework and Rating

Maester uses Common Vulnerability Scoring System (CVSS) as a method of assessing security risk and prioritization for Maester tests. CVSS is an industry standard vulnerability metric. You can learn more about CVSS at [FIRST.org](https://www.first.org/cvss/user-guide).

In addition to the Critical, High, Medium and Low severity levels, Maester also includes an **Info** severity level. This is used for tests that are not vulnerabilities, but rather provide information about the configuration of a system. No remediation is required for these tests, but they may be useful for understanding the configuration of a system.

### Severity Levels

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
| 7.0 - 8.9  | High |
| 4.0 - 6.9  | Medium |
| 0.1 - 3.9  | Low |
| 0  | Info |

In some cases, additional factors unrelated to CVSS score may be used to determine the severity level of a vulnerability. This approach is supported by the [CVSS specification](https://www.first.org/cvss/specification-document):

> Consumers may use CVSS information as input to an organizational vulnerability management process that also considers factors that are not part of CVSS in order to rank the threats to their technology infrastructure and make informed remediation decisions. Such factors may include: number of customers on a product line, monetary losses due to a breach, life or property threatened, or public sentiment on highly publicized vulnerabilities. These are outside the scope of CVSS.

Below are a few examples of vulnerabilities which may result in a given severity level. Please keep in mind that this rating does not take into account details of your installation and are to be used as a guide only.

#### Severity Level: Critical

Vulnerable configurations that score in the critical range usually have most of the following characteristics:

- Exploitation of the vulnerability likely results in unauthorized administrator level access of web applications, full access to application or user data, and/or root-level compromise of servers or infrastructure devices.
- Exploitation is usually straightforward, in the sense that the attacker does not need any special authentication credentials or knowledge about individual victims, and does not need to persuade a target user, for example via social engineering, into performing any special functions.

For critical vulnerabilities, it is advised that you address the issue as soon as possible, unless you have other mitigating measures in place.

#### Severity Level: High

Configuration vulnerabilities that score in the high range usually have some of the following characteristics:

- The configuration vulnerability is difficult to exploit.
- Exploitation could result in elevated privileges.
- Exploitation could result in a significant data loss or downtime.

#### Severity Level: Medium

Configuration vulnerabilities that score in the medium range usually have some of the following characteristics:

- Vulnerabilities that require the attacker to manipulate individual victims via social engineering tactics.
- Denial of service vulnerabilities that are difficult to set up.
- Exploits that require an attacker to reside on the same local network as the victim.
- Vulnerabilities where exploitation provides only very limited access.
- Vulnerabilities that require user privileges for successful exploitation.

#### Severity Level: Low

Vulnerabilities in the low range typically have very little impact on an organization's business. Exploitation of such vulnerabilities usually requires local or physical system access.

### Remediation Timeline

| Severity levels | Recommended resolution timeframes |
| --- | --- |
| Critical | Within 10 days of being identified |
| High  | Within 4 weeks of being identified |
| Medium | Within 12 weeks of being identified |
| Low  | Within 25 weeks of being identified |
| Info  | Not applicable |

## Customizing Severity Levels

Maester allows you to customize the severity levels of the out-of-the-box Maester tests. You can do this by creating a custom configuration file and specifying the severity levels for each test. This allows you to tailor the severity levels to your specific needs and requirements.

To customize severity levels, create a file named `maester-config.json` in your `./tests/Custom` folder.

Provide the severity levels for the tests you want to customize using the format below:

```json
{
  "TestSettings": [
    {
      "Id": "CIS.M365.1.1.1",
      "Severity": "High"
    },
    {
      "Id": "MT.1005",
      "Severity": "Critical"
    }
  ]
}
```

The available severity levels are:

- `Critical`
- `High`
- `Medium`
- `Low`
- `Info`

### Finding Test IDs

To find the ID of a test you want to customize:

1. Run `Invoke-Maester` and look at the test output
2. Check the [Tests Overview](/docs/tests/) documentation
3. Look at the test file source code in the Maester repository

### Defining Severity Levels for Custom Tests

In addition to defining severity levels in `./tests/Custom/maester-config.json`, you can also use the `-Tag` parameter in the `Describe` or `It` block of your Pester tests.

The tag needs to be in the format of `Severity:<SeverityLevel>`.

```powershell
Describe 'My Custom Test' {
    It 'Cus.1001: My custom test' -Tag 'Severity:High' {
        # Your test code here
    }
}
```

### Precedence Order

If a severity level is defined in multiple places, the following precedence order applies (highest to lowest):

1. `./tests/Custom/maester-config.json` (highest priority)
2. `-Tag` parameter in the test file
3. Main `./tests/maester-config.json` (lowest priority)

:::warning Important
Avoid editing the `maester-config.json` file in the `./tests` root folder. Any changes you make to this file will be overwritten when you update the Maester tests.

Always use the `./tests/Custom/maester-config.json` file for customizing severity levels.
:::

## Complete Example

Here's a complete example showing both global settings and test settings in your custom configuration:

```json
{
  "GlobalSettings": {
    "EmergencyAccessAccounts": [
      {
        "UserPrincipalName": "BreakGlass1@contoso.com",
        "Type": "User"
      }
    ]
  },
  "TestSettings": [
    {
      "Id": "MT.1005",
      "Severity": "Critical"
    },
    {
      "Id": "CIS.M365.1.1.1",
      "Severity": "High"
    },
    {
      "Id": "EIDSCA.AF01",
      "Severity": "Medium"
    }
  ]
}
```
