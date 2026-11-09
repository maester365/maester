Checks whether a **complete Windows LAPS or legacy Microsoft LAPS schema pair** is present in Active Directory. Windows LAPS uses `msLAPS-Password` and `msLAPS-PasswordExpirationTime`; legacy Microsoft LAPS uses `ms-Mcs-AdmPwd` and `ms-Mcs-AdmPwdExpirationTime`. Either complete pair satisfies schema readiness. The result identifies both partial pairs so a missing partner attribute cannot masquerade as readiness.

LAPS helps prevent lateral movement from shared local administrator passwords by allowing unique, rotated passwords. **Schema readiness is not deployment proof**: a passing result does not establish that clients use LAPS, rotation works, permissions are restricted or access is audited. The check reads schema *names* (`lDAPDisplayName`) only, never password values; `msLAPS-Password` and `ms-Mcs-AdmPwd` are secrets and must not be collected.

#### Control Type

**Preventive**

#### Security Recommendation

Choose the supported LAPS implementation for the environment, complete its schema attributes and separately configure password policy, read permissions and monitoring. Prefer Windows LAPS when migrating a legacy deployment; do not assume a schema extension itself rotates any password.

#### Remediation action

1. [Extend the Active Directory schema for Windows LAPS](https://learn.microsoft.com/windows-server/identity/laps/laps-scenarios-windows-server-active-directory#update-the-windows-server-active-directory-schema), or complete the schema for an approved legacy Microsoft LAPS deployment.
2. Verify both attributes of the selected implementation are present, then separately deploy LAPS policy, access controls, auditing and password rotation to applicable devices.

#### How the Test Works

The check examines the collected schema attribute names for each complete pair. It reports which Windows LAPS and legacy LAPS names are present or missing; either complete pair passes, but a partial pair alone does not.

#### Related Tests

- **AD-SCH-03 — Schema version and class definitions should be investigated** — `Test-MtAdSchemaVersionEntryCount` — Reviews version and class definitions separately from LAPS readiness.

Schema readiness supports the LAPS prerequisites for NIST SP 800-53 Rev. 5 **IA-5** (authenticator management), but does not alone demonstrate password management is operating. AC-6(2), concerning use of non-privileged accounts for nonsecurity functions, is not assessed by this check.

Microsoft has deprecated legacy Microsoft LAPS and recommends migration to Windows LAPS. A legacy-only pass preserves visibility of an existing implementation; it is not an endorsement of a new legacy deployment or proof that migration is complete.

<!--- Results --->
%TestResult%
