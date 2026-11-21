---
title: Domain Controller Configuration State (Planned)
description: Planned scope and validation requirements for future domain-controller configuration checks.
---

# Domain Controller Configuration State

**Status: Planned; not implemented.** This work adds no dedicated LDAP-configuration collector, configuration-state check, or command. This document does not reserve test IDs or define an executable interface.

## Scope

Future native security checks may assess domain-controller configuration related to LDAP security. This work would be separate from `AD-LDAP-01`, which reports connection evidence; configuration values alone cannot establish how a particular connection was negotiated or enforced.

The planned collection would read, where feasible, effective local settings for LDAP signing and channel binding, relevant Schannel/TLS policy and certificate configuration, and relevant authentication or NTLM restrictions. Collection should use a cached, read-only, narrowly allowlisted service helper under `internal/services/ad`, following the existing AD SMB management pattern in `Get-MtADDomainState` (`SmbConfigurations`) and `Invoke-MtADManagementCommand`. No collector or checks are implemented by this plan.

By default, evidence should cover the contacted domain controller. Each result should identify the responding controller and collection timestamp so configuration from one controller is not attributed to another connection. An operator may explicitly select an inventory of controllers for a broader assessment. A domain-wide conclusion is appropriate only when configuration coverage is complete for all relevant controllers. Preserve denied, unavailable, and other per-controller states; partial or empty data must not be treated as a pass.

Interpretation must account for operating-system defaults and policy precedence, including Server 2025 behavior. Distinguish an absent registry value (which may mean a platform default applies) from a failed read. Do not reduce the assessment to a universal encryption or Kerberos-only switch: the relevant settings and their meaning depend on the policy and platform.

## Boundaries and access

Configuration evidence supports an assessment of configured posture, not proof that every protocol combination is safe or that runtime enforcement behaved as configured. GPO links or definitions do not establish the effective policy on a domain controller. The scope excludes mass protocol probing and any transmission of insecure credentials.

Reading these settings may require explicitly delegated management or registry-read access, or an appropriately constrained JEA endpoint. LDAP read access alone is not sufficient. Documentation should describe the required technical permissions without assuming or automatically granting broad administrative roles. Collection must remain read-only; this work does not include mutations or remediation. See the [Active Directory permission model](./active-directory.md).

## Future implementation and acceptance

If implemented, reusable collection would live under `powershell/internal/services/ad/`; native checks and their guides would live under `tests/ad/domain-controller/`. No implementation files, tests, or collector are created by this plan.

Acceptance should include unit validation of platform defaults and precedence, denied and missing values, partial results, cache use, and service gates. A scoped Windows-runner validation should use approved delegated credentials. The results must not claim full-domain certification without complete relevant-controller coverage.
