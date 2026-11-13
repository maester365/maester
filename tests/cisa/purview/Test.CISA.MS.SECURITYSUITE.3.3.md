The action for the DLP policy SHOULD be set to block sharing sensitive information with everyone.

Blocking sensitive information reduces unauthorized disclosure. This check evaluates every non-disabled rule in an enabled policy that protects credit card numbers, ITINs, and SSNs; a rule must block access and use the **All** scope.

#### Remediation action

1. Sign in to the [Microsoft Purview portal](https://purview.microsoft.com/datalossprevention/policies).
2. Edit every enforced DLP rule that protects all three required sensitive information types.
3. Under **Restrict access or encrypt the content in Microsoft 365 locations**, choose **Block everyone**.
4. Save the rule and turn the policy on immediately.

#### Related links

* [Learn about data loss prevention](https://learn.microsoft.com/purview/dlp-learn-about-dlp)
* [CISA Security Suite baseline - MS.SECURITYSUITE.3.3v1](https://github.com/cisagov/ScubaGear/blob/92e5f2e361e433554f72d38180d11210deb640dc/PowerShell/ScubaGear/baselines/securitysuite.md#mssecuritysuite33v1)

<!--- Results --->
%TestResult%
