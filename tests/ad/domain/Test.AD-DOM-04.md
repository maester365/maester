Reports the RID Manager object's 64-bit available-pool upper and lower allocation boundaries. Their difference is an inventory indicator, not a measured sum of remaining DC-local RID pools. Missing or malformed boundaries are an error, not a passing result.

RIDs form the domain-specific part of SIDs for new users, groups and computers. Exhaustion can prevent creation of new security principals; unexpected changes in available-pool boundaries merit investigation but do not by themselves quantify all usable DC-local allocations.

#### Control Type

**Operational**

#### Security Recommendation

Review the inventory with Active Directory administrators. Confirm missing metadata and assess actual requirements before changing configuration. Trend the RID Manager boundaries, investigate unusual account-creation or join churn, and use dedicated RID diagnostics before making exhaustion claims or changing provisioning controls.

#### How the Test Works

Decodes and reports the RID Manager's 64-bit available-pool value into upper and lower boundaries and their difference. It does not read the domain root as a raw RID pool or sum DC-local pools.

#### Related Tests

- **AD-DOM-03 — Connected domain DC count for review** — `Test-MtAdDomainControllerCount` — Inventories domain controllers.
- **AD-DOM-02 — Machine account quota is zero** — `Test-MtAdMachineAccountQuota` — Reviews machine account quota separately.

#### Related links

* [Active Directory Domain Services documentation](https://learn.microsoft.com/windows-server/identity/ad-ds/active-directory-domain-services)

<!--- Results --->
%TestResult%
