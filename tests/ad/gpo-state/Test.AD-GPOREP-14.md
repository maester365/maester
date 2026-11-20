Inventories distinct GPOs that have at least one enforced link. The informational
**Investigate** result is not a pass/fail judgement about enforcement. This
read-only inventory does not change links or assess whether an override is
appropriate.

#### Control Type

**Operational** — informational inventory

#### Why This Test Matters

Enforcement overrides **Block Inheritance**; it does not block inheritance.
Knowing which policies use enforced links helps reviewers understand where an
inheritance override exists. An unintended override can apply settings to OUs whose
design relies on blocking ordinary inherited policies. Enforcement may be intentional, so its presence alone
does not establish risk or justify removing the flag.

#### Security Recommendation

Review each enforced link's owner, target, and policy purpose. Confirm that the
override matches the intended design and document why it is needed before making
any change to link enforcement.

#### How the Test Works

- Uses the cached GPO and link inventories to count distinct GPOs with one or more
  enforced links, rather than counting individual links.
- A policy with no links is known to have no enforced link when the inventory
  confirms that state. Missing or incomplete link data remains unknown.
- Reports policies with enforced or unknown state. Failed GPO metadata collection
  is an error; unknown enforcement remains visible in the **Investigate** result.
- `AD-GPOL-04` evaluates individual enforced links and fails when any are found;
  this test inventories policies and always reports for investigation.

#### Remediation action

Review each listed policy's owner, enforced link, target, and settings in **Group
Policy Management**. Confirm that the override is required by the policy design
before changing it. If it is not required, assess effects on inheritance and use
the normal change process to remove the enforced flag; do not disable enforcement
blindly. Investigate any unknown enforcement state.

#### Related Tests

- `AD-GPOL-04` evaluates enforced link entries; `AD-GPOL-05` inventories OUs that
  block inheritance.
- `AD-GPOREP-12` inventories disabled links, including links that may also be
  enforced.

#### Related links

- [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%
