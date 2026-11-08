Checks applicable external and forest trusts for SID filtering using their LDAP `trustAttributes` flags.

External downlevel and uplevel trusts without `WITHIN_FOREST` or `FOREST_TRANSITIVE` are checked for `QUARANTINED_DOMAIN` (`0x4`). Forest trusts are checked for `TREAT_AS_EXTERNAL` (`0x40`), which relaxes cross-forest filtering to external-trust rules. Within-forest and MIT realm trusts are excluded. PIM trusts (`0x400`) are counted for manual review rather than failed on this general-purpose rule; they have distinct filtering rules. A missing trust type or bitmask does not count as a pass; investigate configurations and documented exceptions before changing any trust.

The result includes total, evaluated, strong, weak, unknown, and excluded counts, plus details of **every weak or unknown trust**. Selective authentication is a separate control and is not forced as a universal SID-filtering baseline.

#### Remediation action

1. Review affected trust directions and business requirements with domain administrators.
2. Verify SID filtering behavior and SID-history migration needs before changing trust flags; pilot any change to avoid breaking cross-domain access.

#### Related links

* [Microsoft MS-ADTS trust attribute flags](https://learn.microsoft.com/openspecs/windows_protocols/ms-adts/e9a2d23c-c31e-4a6f-88a0-6646fdb51a3c)

<!--- Results --->
%TestResult%
