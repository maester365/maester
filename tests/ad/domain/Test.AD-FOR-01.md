Checks the forest functional level against the highest common level supported by all inventoried forest DCs, not just those in the connected domain. Raising the level enables newer forest capabilities but requires a planned compatibility and recovery assessment.

#### Remediation action

1. Verify OS and supported-level evidence for every forest DC, including foreign-domain records with collection errors.
2. Upgrade incompatible legacy DCs and raise each domain's functional level as required.
3. Raise the forest level only when every DC and domain supports the target. Server 2025 level 10 requires 2025 DCs throughout the forest. Do not interpret an inaccessible DC as healthy or attempt to lower a level based on uncertain inventory.

#### Related links

* [Microsoft: Active Directory functional levels](https://learn.microsoft.com/windows-server/identity/ad-ds/active-directory-functional-levels)
* [Microsoft: Raise domain and forest functional levels](https://learn.microsoft.com/windows-server/identity/ad-ds/plan/raise-domain-forest-functional-levels)

<!--- Results --->
%TestResult%
