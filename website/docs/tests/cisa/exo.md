---
sidebar_label: Exchange Online
description: Implementation of CISA Exchange Online Controls
---

# CISA Controls for Exchange Online

## Overview

The tests in this section verifies that a Microsoft 365 tenant’s **Exchange Online** configuration conforms to the policies described in the Secure Cloud Business Applications ([SCuBA](https://cisa.gov/scuba)) Security Configuration Baseline [documents](https://github.com/cisagov/ScubaGear/blob/main/baselines/README.md).

## Connecting to Azure, Exchange and other services

In order to run all the CISA tests, you need to install and connect to the Azure and Exchange Online modules.

See the [Installation guide](/docs/installation#optional-modules-and-permissions) for more information.

## Tests

| Cmdlet Name | CISA Control ID (Link) |
| - | - |
| Test-MtCisaAutoExternalForwarding | [MS.EXO.1.1v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo11v1) |
| Test-MtCisaSpfRestriction         | [MS.EXO.2.1v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo21v1) |
| Test-MtCisaSpfDirective           | [MS.EXO.2.2v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo22v1) |
| Test-MtCisaDkim                   | [MS.EXO.3.1v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo31v1) |
| Test-MtCisaDmarcRecordExist       | [MS.EXO.4.1v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo41v1) |
| Test-MtCisaDmarcRecordReject      | [MS.EXO.4.2v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo42v1) |
| Test-MtCisaDmarcAggregateCisa     | [MS.EXO.4.3v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo43v1) |
| Test-MtCisaDmarcReport            | [MS.EXO.4.4v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo44v1) |
| Test-MtCisaSmtpAuthentication     | [MS.EXO.5.1v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo51v1) |
| Test-MtCisaContactSharing         | [MS.EXO.6.1v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo61v1) |
| Test-MtCisaCalendarSharing        | [MS.EXO.6.2v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo62v1) |
| Test-MtCisaExternalSenderWarning  | [MS.EXO.7.1v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo71v1) |
| Test-MtCisaDlp                    | [MS.EXO.8.1v2](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo81v2) |
| Test-MtCisaDlpPii                 | [MS.EXO.8.2v2](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo82v2) |
| Test-MtCisaDlpAlternate           | [MS.EXO.8.3v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo83v1) |
| Test-MtCisaDlpBaselineRules       | [MS.EXO.8.4v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo84v1) |
| Test-MtCisaAttachmentFileType     | [MS.EXO.9.1v2](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo91v2) |
| Test-MtCisaAttachmentFileType     | [MS.EXO.9.2v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo92v1) |
| Test-MtCisaAttachmentFileType     | [MS.EXO.9.3v2](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo93v2) |
| Test-MtCisaEmailFilterAlternative | [MS.EXO.9.4v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo94v1) |
| Test-MtCisaBlockExecutable        | [MS.EXO.9.5v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo95v1) |
| Test-MtCisaAttachmentFilter       | [MS.EXO.10.1v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo101v1) |
| Test-MtCisaMalwareAction          | [MS.EXO.10.2v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo102v1) |
| Test-MtCisaMalwareZap             | [MS.EXO.10.3v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo103v1) |
| Test-MtCisaImpersonation          | [MS.EXO.11.1v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo111v1) |
| Test-MtCisaImpersonationTip       | [MS.EXO.11.2v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo112v1) |
| Test-MtCisaMailboxIntelligence    | [MS.EXO.11.3v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo113v1) |
| Test-MtCisaAntiSpamAllowList      | [MS.EXO.12.1v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo121v1) |
| Test-MtCisaAntiSpamSafeList       | [MS.EXO.12.2v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo122v1) |
| Test-MtCisaMailboxAuditing        | [MS.EXO.13.1v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo131v1) |
| Test-MtCisaSpamFilter             | [MS.EXO.14.1v2](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo141v2) |
| Test-MtCisaSpamAction             | [MS.EXO.14.2v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo142v1) |
| Test-MtCisaSpamBypass             | [MS.EXO.14.3v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo143v1) |
| Test-MtCisaSpamAlternative        | [MS.EXO.14.4v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo144v1) |
| Test-MtCisaSafeLink               | [MS.EXO.15.1v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo151v1) |
| Test-MtCisaSafeLinkDownloadScan   | [MS.EXO.15.2v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo152v1) |
| Test-MtCisaSafeLinkClickTracking  | [MS.EXO.15.3v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo153v1) |
| Test-MtCisaExoAlert               | [MS.EXO.16.1v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo161v1) |
| Test-MtCisaExoAlertSiem           | [MS.EXO.16.2v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo162v1) |
| Test-MtCisaAuditLog               | [MS.EXO.17.1v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo171v1) |
| Test-MtCisaAuditLogPremium        | [MS.EXO.17.2v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo172v1) |
| Test-MtCisaAuditLogRetention      | [MS.EXO.17.3v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo173v1) |