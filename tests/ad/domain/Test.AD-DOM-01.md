Checks that the connected domain's functional level equals the highest common level supported by its DCs. A lower level prevents use of newer directory capabilities; a level above collected DC support requires investigation of incompatible or stale inventory.

#### Remediation action

1. Verify the connected domain's DC inventory and operating-system releases; do not mix in other forest domains.
2. Plan upgrades of legacy DCs and review application compatibility and recovery requirements.
3. Raise the domain functional level only after every DC supports it. Windows Server 2025 uses level 10; Server 2016/2019/2022 use level 7. Missing or conflicting metadata must be resolved first.

#### Related links

* [Microsoft: Active Directory functional levels](https://learn.microsoft.com/windows-server/identity/ad-ds/active-directory-functional-levels)
* [Microsoft: Raise domain and forest functional levels](https://learn.microsoft.com/windows-server/identity/ad-ds/plan/raise-domain-forest-functional-levels)

<!--- Results --->
%TestResult%
