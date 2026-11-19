Checks whether any collected OU has `gpOptions` equal to `1`, which blocks Group Policy inheritance. It fails when one or more OUs block inheritance and passes when none do. An unset `gpOptions` uses the default behavior, with inheritance enabled; it is not an unknown value. If OU/link-container collection fails, the test errors rather than reporting a clean result.

Blocking inheritance can prevent parent-linked settings from flowing to child OUs. Enforced parent links still apply. The result reports total OUs and the number blocking inheritance, with affected OUs listed when present.

#### Remediation action

Review each listed OU with its owner and confirm the business or technical reason for blocking inheritance. Verify that required security settings are otherwise applied. Remove the block only after checking policy scope and the effect on child OUs.

#### Related links

* [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%
