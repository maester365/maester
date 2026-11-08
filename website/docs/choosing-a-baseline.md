---
title: Choosing a baseline
description: The test suites that ship with Maester, which requirements each one serves, and how to run the combination that fits your organisation.
---

# Choosing a baseline

Maester does not pick a security framework for you. It ships several suites of tests, each built from a different
source, and you run the ones that match the requirements your organisation has to meet. This page explains what
each suite is, helps you match suites to your requirements, and shows how to make your choice the default for every
run.

## The suites that ship with Maester

| Suite | Source | What it checks | `-Suite` |
| --- | --- | --- | --- |
| [Maester](/docs/tests/maester) | The Maester community | Entra ID, Conditional Access, privileged access, app registrations, Exchange, Teams, Defender, Intune, Azure DevOps, AI agents and more. Written from real attacks and misconfigurations seen in tenants. | `Maester` |
| [CIS](/docs/tests/cis) | [CIS Microsoft 365 Foundations Benchmark](https://www.cisecurity.org/benchmark/microsoft_365) and CIS GitHub Benchmark | The benchmark's recommendations that can be read from the service. A few need a person to confirm them and report **Investigate**. Each result names its recommendation and its level, L1 or L2. | `CIS` |
| [CISA](/docs/tests/cisa) | [CISA SCuBA](https://github.com/cisagov/ScubaGear) Secure Configuration Baselines | The automatable SCuBA policies for Entra ID, Exchange Online and SharePoint Online. Each requirement carries its NIST SP 800-53 references. | `CISA` |
| [ASD](/docs/tests/asd) | [ASD Essential Eight maturity model](https://www.cyber.gov.au/business-government/asds-cyber-security-frameworks/essential-eight/essential-eight-maturity-model) and [Information security manual](https://www.cyber.gov.au/ism) (ISM) | Entra ID and Intune settings for the Essential Eight requirements and ISM controls that can be read from Microsoft 365, such as phishing-resistant MFA, just-in-time administration and Office macro hardening. Each result names its ISM control and, for Essential Eight, the maturity level and mitigation strategy. | `ASD` |
| [EIDSCA](/docs/tests/eidsca) | [Entra ID Security Config Analyzer](https://github.com/Cloud-Architekt/AzureAD-Attack-Defense) | Entra ID tenant settings (authorisation, consent, authentication methods, password protection) against recommended values. | `EIDSCA` |
| [ORCA](/docs/tests/orca) | [Office 365 Recommended Configuration Analyzer](https://github.com/cammurray/orca) | Exchange Online Protection and Defender for Office 365: anti-spam, anti-phishing, Safe Links, Safe Attachments. | `ORCA` |
| [Active Directory](/docs/tests/ad) | The Maester community | On-premises Active Directory inventory and configuration. Runs only after `Connect-Maester -Service ActiveDirectory`. | `AD` |

[Maester Packs](packs/index.md) add more, for example the [Zero Trust Assessment pack](packs/zero-trust-assessment.md),
which runs Microsoft's Zero Trust Assessment and shows its results in the same report.

By default, `Invoke-Maester` runs every built-in suite except Active Directory, and leaves out preview and
long-running tests.

## Match suites to your requirements

Start from what your organisation has to show, not from the suites. Most organisations combine two or three rows.

| If your requirement is… | Run | Why |
| --- | --- | --- |
| Evidence against the CIS Microsoft 365 Foundations Benchmark (an auditor, an insurer, a customer questionnaire) | `CIS` | Each result names its CIS recommendation and level. |
| Alignment with CISA SCuBA, or a control set built on NIST SP 800-53 | `CISA` | Each result names its SCuBA policy, and the NIST controls it relates to. |
| Alignment with the ASD Essential Eight or the ISM (Australian government and organisations that follow ASD guidance) | `ASD` | Each result names its ISM control, and for Essential Eight the maturity level (ML1 to ML3) and mitigation strategy. A passing check is evidence for its control, not an Essential Eight assessment. |
| An internal standard, or a framework Maester does not ship (ISO/IEC 27001, NIST CSF, a sector regulation) | `Maester`, `EIDSCA`, plus your own tests mapped to that framework | Maester's tests cover the technical settings most frameworks ask for. Map your own tests to your framework's requirements (see [below](#your-own-framework)). |
| Hardening Entra ID against identity attacks | `Maester`, `EIDSCA` | Conditional Access, privileged access, consent and authentication settings. |
| Reducing phishing and malware by email | `ORCA`, and the Exchange and Defender tests of `Maester` | Mail flow protection and its policies. |
| A Zero Trust programme | The [Zero Trust Assessment pack](packs/zero-trust-assessment.md) and `Maester` | Microsoft's assessment by Zero Trust pillar, with Maester's checks in the same report. |
| Hybrid identity with on-premises Active Directory | `AD`, alongside the others | The on-premises side of the identity that Entra ID trusts. |
| No formal requirement yet | Everything (the default) | You see the whole picture and narrow it down later. |

### Overlap between suites

Several suites check the same setting from their own source. For example, blocking legacy authentication is
checked by [MT.1009](/docs/tests/MT.1009), [CIS.M365.5.2.2.3](/docs/tests/CIS.M365.5.2.2.3) and the CISA
suite. That is expected: each result reports against its own framework. If you need one framework view, run its
suite. To add tests from other suites, run them in a separate invocation that names their own suite, for example
`Invoke-Maester -Suite Maester -TestId MT.1009`. The selectors must all match, so `-Suite CIS -TestId MT.1009` runs
nothing, and leaving `-Suite` out does not help when your configuration sets `Selection.Suite`: the configured suite
still applies.

## Make your choice the default

Run a combination on the command line:

```powershell
Invoke-Maester -Suite CIS, Maester
```

Or save it in the `Selection` section of `maester-config.json`, so every run, including scheduled ones, uses the
same baseline:

```json
{
  "Selection": {
    "Suite": ["CIS", "Maester"]
  }
}
```

Selectors combine: values of one selector are alternatives, different selectors must all match. To focus on the most
urgent tests of your baseline first:

```powershell
Invoke-Maester -Suite CISA -Severity Critical, High
```

See the [run configuration reference](configuration/run-configuration.md) for every key of `Selection`, and
[Invoke-Maester](commands/Invoke-Maester.mdx) for all the selectors (`-Product`, `-Feature`, `-Area`, `-Severity`,
`-Suite`, `-TestId`).

## Adapt the baseline to your organisation

No baseline fits an organisation without changes. Record your decisions in `maester-config.json`, so they are
visible and reviewed rather than ignored:

- **A recommendation you have decided not to follow:** turn the test off with a reason. The report shows it as
  **Not run** with your reason, so an auditor can see the decision.
- **A risk that matters more or less to you:** change the test's severity.
- **A threshold that differs from the default:** change the test's parameters.

```json
{
  "TestSettings": [
    { "Id": "CIS.M365.1.3.3", "Enabled": false, "Reason": "Calendar sharing approved by risk committee, RISK-042" },
    { "Id": "MT.1005", "Severity": "Critical" },
    { "Id": "MT.1198", "Parameters": { "MaximumValidityDays": 180 } }
  ]
}
```

Keep this file in version control so that every change to your baseline has an author, a date and a review.
See [Configure Maester](configuration/overview.md).

## Your own framework

If your organisation has its own standard, or follows a framework Maester does not ship, write tests for the
requirements Maester does not already cover and map each one to its requirement with the `Control` attribute. A
framework file in your suite gives Maester the framework's name, version and requirements, and every result then
names the requirement it implements. See
[Benchmarks and framework files](writing-tests/index.mdx#benchmarks-and-framework-files).

Many built-in tests already name the NIST SP 800-53 controls they support in their `Control` attribute, and most
frameworks publish a mapping to NIST SP 800-53, which helps you find the built-in tests that serve a requirement.
