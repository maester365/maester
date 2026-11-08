Checks applicable external and forest trusts for SID filtering using their LDAP `trustAttributes` flags.

SID filtering protects trust boundaries from unauthorized SID history and limits the reach of a compromised trusted domain. A weak flag warrants investigation, but migration and privileged-identity scenarios require the trust's specific context before remediation.

External downlevel and uplevel trusts without `WITHIN_FOREST` or `FOREST_TRANSITIVE` are checked for `QUARANTINED_DOMAIN` (`0x4`). Forest trusts are checked for `TREAT_AS_EXTERNAL` (`0x40`), which relaxes cross-forest filtering to external-trust rules. Within-forest and MIT realm trusts are excluded. PIM trusts (`0x400`) are counted for manual review rather than failed on this general-purpose rule; they have distinct filtering rules. A missing trust type or bitmask does not count as a pass; investigate configurations and documented exceptions before changing any trust.

The result includes total, evaluated, strong, weak, unknown, and excluded counts, plus details of **every weak or unknown trust**. Selective authentication is a separate control and is not forced as a universal SID-filtering baseline.

#### Control Type

**Operational**

#### Security Recommendation

Enable appropriate filtering on applicable external trusts and review forest trust flags and exceptions with administrators; retain necessary SID-history migration paths only with documented risk controls.

#### Remediation action

1. Review affected trust directions and business requirements with domain administrators.
2. Verify SID filtering behavior and SID-history migration needs before changing trust flags; pilot any change to avoid breaking cross-domain access.

#### How the Test Works

The check classifies LDAP trust records using `trustType` and `trustAttributes`; external trusts require `QUARANTINED_DOMAIN` and forest trusts without `TREAT_AS_EXTERNAL` meet the general filtering rule. It reports weak and unknown trusts, excluding within-forest and realm trusts and routing PIM trusts to manual review. Unknown flags cannot be counted as strong.

#### Related Tests

- **AD-TRUST-02 — Trust inter-forest count should be investigated** — `Test-MtAdTrustInterForestCount` — Inventories inter-forest trusts.
- **AD-TRUST-01 — Trust count and configuration should be investigated** — `Test-MtAdTrustTotalCount` — Inventories trust configuration.

#### Related links

* [Microsoft MS-ADTS trust attribute flags](https://learn.microsoft.com/openspecs/windows_protocols/ms-adts/e9a2d23c-c31e-4a6f-88a0-6646fdb51a3c)

<!--- Results --->
%TestResult%
