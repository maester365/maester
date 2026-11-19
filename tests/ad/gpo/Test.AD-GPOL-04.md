Counts GPO link entries marked **Enforced**, which override inheritance blocking at lower levels. The test reports a finding when enforced links exist; enforcement can be intentional, but can make a policy apply beyond the scope administrators expect.

#### Remediation action

Review each enforced link's purpose, target, and settings in **Group Policy Management**. Retain enforcement only when required by the policy design; otherwise remove the enforced flag after assessing the effect on inherited policy.

#### Related links

* [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%
