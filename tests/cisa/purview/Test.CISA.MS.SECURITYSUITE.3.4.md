User notifications to help educate users on the proper use of sensitive information SHOULD be enabled in the DLP policy.

User notifications provide feedback when a DLP policy detects sensitive information. This check requires at least one user to be notified by every non-disabled rule in an enabled policy that protects credit card numbers, ITINs, and SSNs.

#### Remediation action

1. Sign in to the [Microsoft Purview portal](https://purview.microsoft.com/datalossprevention/policies).
2. Edit every enforced DLP rule that protects all three required sensitive information types.
3. Enable user notifications and select at least one user-notification method. In Microsoft 365 locations, enable policy tips or email notifications where available.
4. Save the rule and turn the policy on immediately.

#### Related links

* [Learn about data loss prevention](https://learn.microsoft.com/purview/dlp-learn-about-dlp)
* [CISA Security Suite baseline - MS.SECURITYSUITE.3.4v1](https://github.com/cisagov/ScubaGear/blob/92e5f2e361e433554f72d38180d11210deb640dc/PowerShell/ScubaGear/baselines/securitysuite.md#mssecuritysuite34v1)

<!--- Results --->
%TestResult%
