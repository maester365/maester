---
title: "MT.1182 - Entra managed and verified domains should have mature DMARC policy (p=reject, pct=100)"
description: "Ensure every managed and verified Entra domain has a mature DMARC policy published at the registrable domain, with `p=reject` and `pct=100`."
slug: /tests/MT.1182
className: generated-test-doc
sidebar_class_name: hidden
hide_table_of_contents: true
keywords:
  - "Maester"
  - "Microsoft 365 security"
  - "MT.1182"
  - "Entra"
---

# MT.1182 - Entra managed and verified domains should have mature DMARC policy (p=reject, pct=100)

## Overview

Ensure every managed and verified Entra domain has a mature DMARC policy published at the registrable domain, with `p=reject` and `pct=100`.

Without a DMARC policy available for each domain, recipients may improperly handle SPF and DKIM failures, possibly enabling spoofed emails to reach end users' mailboxes. Publishing DMARC records protects the domains and all subdomains.

This test:

- Passes when `p=reject` and `pct=100`
- Fails with low severity when `p=quarantine` or `pct < 100`
- Fails with medium severity when `p=none`
- Fails with high severity when no usable DMARC record is found

#### Remediation action:

DMARC is not configured directly through the Microsoft Admin Center, but rather via DNS records hosted by the agency's domain. As such, implementation varies depending on how an agency manages its DNS records. See [Form the DMARC TXT record for your domain | Microsoft Learn](https://learn.microsoft.com/en-us/microsoft-365/security/office-365-security/email-authentication-dmarc-configure?view=o365-worldwide#step-4-form-the-dmarc-txt-record-for-your-domain) for Microsoft guidance.

A DMARC record published at the second-level domain will protect all subdomains. In other words, a DMARC record published for `example.com` will protect both `a.example.com` and `b.example.com`, but a separate record would need to be published for `c.example.gov`.

To test your DMARC configuration, consider using one of many publicly available web-based tools. Additionally, DMARC records can be requested using the PowerShell tool `Resolve-DnsName`. For example:

`Resolve-DnsName _dmarc.example.com txt`

#### Related links

- [Microsoft Learn - Set up DMARC](https://learn.microsoft.com/en-us/defender-office-365/email-authentication-dmarc-configure)
- [NCSC - Protect Parked Domains](https://www.ncsc.gov.uk/blog-post/protecting-parked-domains)
- [CISA 4 Domain-Based Message Authentication, Reporting, and Conformance (DMARC) - MS.EXO.4.1v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo41v1)

## Test Metadata

| Field | Value |
| --- | --- |
| Test ID | MT.1182 |
| Suite | Maester |
| Category | Entra |
| PowerShell test | [Test-MtDomainsDmarcRecordMaturity](/docs/commands/Test-MtDomainsDmarcRecordMaturity) |
| Tags | Entra, Maester, MT.1182 |

## Source

- Pester test: `tests\Maester\Entra\Test-MtDomainsDmarcRecordMaturity.Tests.ps1`
- PowerShell source: `powershell\public\maester\entra\Test-MtDomainsDmarcRecordMaturity.ps1`
