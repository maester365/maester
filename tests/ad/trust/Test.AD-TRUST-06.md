Inventories **all trusts** with targets, directions, types, validation date/age (or Unknown), and counts known dates older than `StaleThresholdDays` (default 60), unknown dates, and known dates within threshold.

The safe LDAP trust inventory does **not** return `LastValidated`; it has no official persisted last-validation timestamp. Consequently typical runs show unknown status for all trusts. `whenChanged`/`Modified` records object updates, **not** validation. This remains an investigation result, never a pass/fail stale-trust assertion, until a viable trustworthy validation data source exists. Known timestamps, if supplied by a future verified source, are compared against the configured threshold.

#### Control Type

**Operational**

#### Security Recommendation

Document trust ownership and purpose, verify connectivity using an approved independent process and retire only confirmed obsolete trusts. Unknown validation dates should prompt review, not automatic deletion.

#### Remediation action

1. Review trust ownership, necessity, and connectivity with domain administrators.
2. Use an independently approved validation procedure to evaluate reachability and document any results; do not substitute trust object modification time or read trust secrets.

#### How the Test Works

The check inventories trust targets and available validation timestamps, comparing known dates to `StaleThresholdDays` (default 60). Safe LDAP usually yields Unknown for each date; the check cannot assert staleness from an absent `LastValidated` field.

#### Related Tests

- **AD-TRUST-01 — Trust count and configuration should be investigated** — `Test-MtAdTrustTotalCount` — Inventories trust configuration.
- **AD-TRUST-03 — Applicable trusts should have strong SID filtering with no weak findings** — `Test-MtAdTrustQuarantinedCount` — Reviews SID filtering separately.

<!--- Results --->
%TestResult%
