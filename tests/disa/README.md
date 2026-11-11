# DISA STIGs

Checks that verify a Microsoft 365 tenant against the
[Security Technical Implementation Guides](https://public.cyber.mil/stigs/) (STIGs) that the US Defense Information
Systems Agency (DISA) publishes for Microsoft's cloud services:

| Framework key | STIG | Release |
| --- | --- | --- |
| `disa-stig-entra-id` | Microsoft Entra ID STIG | V1R2 (30 Sep 2026) |
| `disa-stig-intune-mdm` | Microsoft Intune MDM Service Desktop and Mobile STIG | V1R2 (01 Jul 2026) |
| `disa-stig-intune-desktop` | Microsoft Intune MDM Service Desktop STIG | V1R1 (24 Sep 2024) |

DISA publishes no STIG for Exchange Online, SharePoint Online, Teams or Purview. The Defender for Endpoint and
Active Directory STIGs are not covered yet, and the device STIGs (Windows 11 and others) are checked on devices,
not in the tenant.

## Layout

- `suite.json` declares the suite (`DISA`) and its three frameworks.
- `frameworks/<key>.json` is the catalogue of each STIG: one entry per rule with its `Id` (the vulnerability ID,
  `V-270233`), `Category` (CAT I to CAT III), `RuleId` and `StigId`, and the NIST SP 800-53 Rev. 5 controls of the
  CCIs the rule lists as `Related`. It holds every rule of the STIG, including those that no test checks.
- `Test.DISA.<V-ID>.ps1` and `.md` are the checks, in one folder, because the rules of one STIG are fixed in more
  than one product (the Intune STIGs ask for settings in Microsoft Entra ID and the Microsoft 365 admin center).

## IDs and mapping

A check is named after the STIG rule it implements: `DISA.V-270233` implements V-270233. Vulnerability IDs are
unique across STIGs, so the ID also tells you which STIG the rule comes from. The attribute names the rule in its
framework, `Control = 'disa-stig-entra-id:V-270233'`, and the framework file adds the rule's NIST controls to the
result. The `Benchmark` of a result carries the rule's `Category`, `RuleId` and `StigId`.

## Checks that another suite already has

Most DISA rules ask for a setting that a CIS, CISA or Maester test already checks. The DISA check is then a shim
that returns that test's result, with DISA's values as parameters where they differ (`DISA.V-270208` runs
CIS.M365.5.2.3.8 with a lockout threshold of 3 and a duration of 900 seconds). Rules the Intune and Entra ID STIGs
share (idle timeout, inactive accounts, lockout, MFA, password lifetime) are checked once and the other rules are
shims. See
[Tests that another suite already has](https://maester.dev/docs/next/writing-tests#tests-that-another-suite-already-has).

## Rules without a check

| Rule | Why |
| --- | --- |
| V-267315 (Intune Desktop: DoD banner the user must acknowledge) | The Entra sign-in page text shows a banner but cannot force an acknowledgement; DISA.V-270209 checks the banner. |
| V-267372, V-267373, V-267374, V-267375, V-267379 (Intune Desktop: notify the ISSO of account creation, change, disabling, removal and enabling) | DISA expects alerts from a log management server or SIEM, which the tenant does not show. |

## DoD-specific and conflicting rules

- The DoD Notice and Consent Banner (`DISA.V-270209`) fails outside DoD by design.
- The password lifetime rules (`DISA.V-270239`, 180 days; `DISA.V-267355`, 60 days) conflict with CIS.M365.1.3.1,
  which asks that passwords never expire. A tenant passes one side at most.

The checks with logic of their own are `Preview` until they have run against a DoD tenant.
