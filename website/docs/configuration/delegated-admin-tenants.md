---
title: Delegated Admin Tenants
sidebar_position: 2.5
---

# Configuring Delegated Admin Tenants

MT.1258 assesses other Microsoft Entra tenants that administer your tenant through two paths:

- **Tenant Governance**: a governing tenant whose governance relationship assigns Microsoft Entra roles in your tenant to its groups.
- **Granular delegated admin privileges (GDAP)**: partner tenants identified through remote tenant groups, excluding tenants already identified through Tenant Governance. To the best of current knowledge, remote tenant groups are the strongest customer-side signal that names a GDAP partner; the [MT.1258 guide](https://maester.dev/docs/tests/MT.1258) compares the other signals and explains why they were not chosen. The customer-side APIs do not expose a complete GDAP relationship inventory; verify relationships without exposed remote groups on the Microsoft 365 **Partner relationships** page.

Each is a trust path into your tenant: an attacker who compromises the other tenant can use the roles it holds. The `DelegatedAdminTenants` setting is the allowlist for these GDAP and Tenant Governance relationships (any governance relationship that is not terminated, including one whose termination is pending). Legacy DAP, unrelated foreign Microsoft Entra role assignments and cross-tenant service-provider marks are outside this check's verdict. Service-provider marks can remain after relationships end and are shown only for information.

## Why Configure Delegated Admin Tenants?

Maester cannot tell a partner you work with from one you no longer know about. Listing your delegated admin tenants:

- **Turns an inventory into a check**: a tenant that is not on the list fails the check, and the result names it.
- **Points at the risk**: the result names the privileged Microsoft Entra roles, such as Global Administrator, that a tenant that is not allowlisted holds in your tenant.
- **Documents your partners**: the list records which tenants may administer your tenant.

Without the setting, no tenant is allowlisted, so every tenant identified through an in-scope relationship fails the check.

## Configuration Format

Delegated admin tenants are configured in the `GlobalSettings` section of your custom `maester-config.json` file, like the [emergency access accounts](./emergency-access-accounts.md).

```json
{
  "GlobalSettings": {
    "DelegatedAdminTenants": [
      "00000000-0000-0000-0000-000000000000",
      "11111111-1111-1111-1111-111111111111"
    ]
  }
}
```

Each entry is the Microsoft Entra tenant ID of a governing or partner tenant, as a string. An entry that is not a tenant ID is ignored, with a warning. The result shows the name of each tenant, so the list does not need one.

## Finding the Tenant IDs

Run the check once without the setting. Its result lists identified governing tenants and GDAP partners, with their names and tenant IDs, under **Tenant Governance** and **GDAP and informational CSP partners**. Add the in-scope tenants you approve, and remove unnecessary relationships. Legacy DAP and informational CSP partners do not need to be allowlisted for this check.

**Service providers in cross-tenant access settings** is informational only and never changes the verdict. Optional tenant discovery adds inbound admin-app user/application metrics, not additional tenants to assess. It is enabled by default, skipped when Microsoft Entra ID Governance licensing is unavailable, and can be disabled with `TestSettings` for MT.1258: `"Parameters": { "IncludeTenantDiscovery": false }`. Discovery and other enrichment failures do not affect the verdict.

You can also find them in the admin portals:

- **Tenant Governance**: in the [Microsoft Entra admin center](https://entra.microsoft.com), browse to **Tenant governance** > **Governing tenants**.
- **GDAP**: in the Microsoft 365 admin center, open [Partner relationships](https://go.microsoft.com/fwlink/p/?linkid=2074649) under **Settings**.

## Tests that use this setting

| Test | Description |
| --- | --- |
| [MT.1258](https://maester.dev/docs/tests/MT.1258) | Only allowlisted tenants can administer this tenant through GDAP or Tenant Governance. |
