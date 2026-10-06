---
name: maester-test-expert
description: >-
  Write, validate, and document Maester security checks for Microsoft 365 tenants.
  Use when asked to create, edit, review, or debug a Maester check (a native test:
  Test.<ID>.ps1 with a [MaesterTest] attribute plus Test.<ID>.md), its tagging, or a
  user's custom test. Covers the [MaesterTest] attribute, Service/CompatibleLicense
  gates, test parameters, Graph API data retrieval, Add-MtTestResultDetail formatting,
  the tagging taxonomy (CIS, CISA, EIDSCA, ORCA, MT), remediation guidance,
  Entra ID, Exchange, SharePoint, Teams, Defender, Conditional Access, and the
  validation checklist for new checks.
---

# Maester Test Expert (pointer)

The canonical skill content lives at [`.github/skills/maester-test-expert/SKILL.md`](../../../.github/skills/maester-test-expert/SKILL.md).

**Read that file and follow it** for all Maester check authoring: file layout, the native test and markdown templates, the tagging taxonomy, the validation checklist, and remediation patterns.

This pointer file exists so Claude Code can auto-suggest the Maester check workflow when it detects a relevant context. The full content is shared with the Copilot skill at the same path under `.github/skills/`, making `.github/skills/maester-test-expert/SKILL.md` the single source of truth for both tools.
