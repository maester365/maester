Inventories **all trusts** with targets, directions, types, validation date/age (or Unknown), and counts known dates older than `StaleThresholdDays` (default 60), unknown dates, and known dates within threshold.

The safe LDAP trust inventory does **not** return `LastValidated`; it has no official persisted last-validation timestamp. Consequently typical runs show unknown status for all trusts. `whenChanged`/`Modified` records object updates, **not** validation. This remains an investigation result, never a pass/fail stale-trust assertion, until a viable trustworthy validation data source exists. Known timestamps, if supplied by a future verified source, are compared against the configured threshold.

#### Remediation action

1. Review trust ownership, necessity, and connectivity with domain administrators.
2. Use an independently approved validation procedure to evaluate reachability and document any results; do not substitute trust object modification time or read trust secrets.

<!--- Results --->
%TestResult%
