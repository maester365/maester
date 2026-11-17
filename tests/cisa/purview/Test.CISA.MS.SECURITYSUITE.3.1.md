A DLP policy SHALL protect PII and sensitive information, as defined by the agency, including at a minimum credit card numbers, U.S. Individual Taxpayer Identification Numbers (ITIN), and U.S. Social Security numbers (SSN).

> Reference your organization's policy defining restricted information.

Rationale: A DLP policy is a defense-in-depth safeguard: a user or attacker must first gain access to data before it can help prevent disclosure. It can detect and prevent users from inadvertently sharing sensitive information with people who should not have access to it.

This check requires a Security & Compliance PowerShell connection; separate Exchange Online and Microsoft Graph connections are not required.

#### Remediation action:

1. Sign in to the [Microsoft Purview portal](https://purview.microsoft.com/datalossprevention/policies).
2. Under **Solutions**, open **Data loss prevention** and select **Policies**.
3. Create or edit an enabled DLP policy that covers the locations relevant to your agency.
4. Add a rule with the condition **Content contains** and select **Sensitive info types**.
5. Add information types that protect information sensitive to the agency.

    At a minimum, the agency should protect:

    - Credit card numbers
    - U.S. Individual Taxpayer Identification Numbers (ITIN)
    - U.S. Social Security Numbers (SSN)
    - All agency-defined PII and sensitive information

6. Save the rule and turn the policy on immediately.

Blocking actions and user notifications are assessed separately by CISA.MS.SECURITYSUITE.3.3 and CISA.MS.SECURITYSUITE.3.4.

#### Related links

* [Purview admin center - Data loss prevention policies](https://purview.microsoft.com/datalossprevention/policies)
* [CISA Security Suite baseline - MS.SECURITYSUITE.3.1v1](https://github.com/cisagov/ScubaGear/blob/92e5f2e361e433554f72d38180d11210deb640dc/PowerShell/ScubaGear/baselines/securitysuite.md#mssecuritysuite31v1)
* [CISA ScubaGear Security Suite implementation](https://github.com/cisagov/ScubaGear/blob/92e5f2e361e433554f72d38180d11210deb640dc/PowerShell/ScubaGear/Rego/SecuritySuiteConfig.rego)

<!--- Results --->
%TestResult%