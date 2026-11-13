The DLP policy SHOULD be applied to Exchange, OneDrive, SharePoint, Teams chat, and Devices.

To prevent unauthorized disclosure, enabled policies with non-disabled rules protecting credit card numbers, ITINs, and SSNs need to cover all required Microsoft 365 workloads and device locations.

#### Remediation action

1. Sign in to the [Microsoft Purview portal](https://purview.microsoft.com/datalossprevention/policies).
2. Edit or create an enabled DLP policy whose rules protect credit card numbers, U.S. Individual Taxpayer Identification Numbers, and U.S. Social Security numbers.
3. Apply qualifying policies to **Exchange**, **SharePoint**, **OneDrive**, **Teams**, and **Devices**. For each workload, select **All** locations.
4. Turn the policy on immediately and save it.

#### Related links

* [Learn about data loss prevention](https://learn.microsoft.com/purview/dlp-learn-about-dlp)
* [CISA Security Suite baseline - MS.SECURITYSUITE.3.2v1](https://github.com/cisagov/ScubaGear/blob/92e5f2e361e433554f72d38180d11210deb640dc/PowerShell/ScubaGear/baselines/securitysuite.md#mssecuritysuite32v1)

<!--- Results --->
%TestResult%
