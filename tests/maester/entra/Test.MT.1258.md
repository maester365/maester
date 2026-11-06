Only allowlisted tenants should administer this tenant through **GDAP or Microsoft Entra Tenant Governance**.

Both features create a trust path into your tenant: an attacker who compromises a governing tenant or GDAP partner can use its delegated privileges. This check compares the following tenants with the [`DelegatedAdminTenants`](https://maester.dev/docs/configuration/delegated-admin-tenants) allowlist:

* **Tenant Governance:** governing tenants of relationships in which your tenant is governed and that are not terminated. A relationship whose termination was requested (`terminationRequestedByGoverningTenant`) still grants its roles, so it counts. Relationships in which your tenant governs another tenant are outbound and not assessed.
* **GDAP:** partner tenants identified through Microsoft Graph's **remote tenant groups**, excluding tenants already identified through Tenant Governance. These groups are exposed after delegated privileges are established through Partner Center or Tenant Governance.

The customer-side APIs do not expose the complete GDAP relationship inventory, its authorized roles, expiration dates or auto-extension settings. A relationship that exposes no remote tenant groups cannot be identified as GDAP by this check. Review the [Partner relationships](https://go.microsoft.com/fwlink/p/?linkid=2074649) page for the full inventory. A passing result is limited to the relationships visible through these sources.

#### Why remote tenant groups identify GDAP partners

To the best of current knowledge, remote tenant groups are the strongest signal visible from the customer tenant that **names** a GDAP partner, so this check uses them as its only GDAP anchor. Other signals were considered and not used for the verdict:

| Signal in your tenant | Names the partner | Why it is not the anchor |
| --- | --- | --- |
| **Remote tenant groups** (chosen) | Yes, tenant and group | Microsoft documents them as discoverable once delegated admin is set up through Partner Center or Tenant Governance. Whether they are removed when a relationship ends is not documented. |
| GDAP service principal *Partner customer delegated admin offline processor* (`a3475900-ccec-4a69-98f5-a65cd5dc5306`) | No | Documented to be removed when the **last** GDAP relationship ends, but it exists once per tenant and does not say which partner the relationship is with. |
| GDAP service principal *Partner customer delegated administration* (`2832473f-ec63-45fb-976f-5d45a7d4bb91`) | No | Required when a GDAP relationship is accepted, and it sets up the service-provider mark in the cross-tenant access settings. It exists once per tenant, does not name the partner, and is not documented to be removed when relationships end. |
| Cross-tenant access service-provider mark (`isServiceProvider`) | Yes | Set when a GDAP relationship is accepted, but it can remain after the relationship ends. |
| CSP partner list (`directory/partners`) | Yes | Describes reseller and legacy DAP partnerships, not GDAP. |
| GDAP relationships (`delegatedAdminRelationships`) | Yes | Readable only by the partner's tenant. |

If Microsoft adds a customer-side API for GDAP relationships, it should replace this anchor.

Source for both GDAP service principals: [GDAP FAQ for customers: What are the two Microsoft Entra GDAP service principals that are created in the customer's tenant?](https://learn.microsoft.com/partner-center/customers/gdap-migration-faq#what-are-the-two-microsoft-entra-gdap-service-principals-that-are-created-in-the-customer-s-tenant-)

**Outside the verdict:** legacy DAP, CSP partner metadata, unrelated foreign Microsoft Entra role assignments, inbound sign-in activity, and cross-tenant access service-provider marks. In particular, a service-provider mark can remain after a relationship ends; it does not prove that GDAP is active, even alongside partner metadata or role assignments.

#### Allowlist and results

List approved governing and GDAP partner tenant IDs in `GlobalSettings`:

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

Without an allowlist, every tenant identified through an in-scope relationship fails. Allowlisted relationships are counted rather than listed in the assessment tables. Known privileged roles are highlighted to help prioritize review; role information does not independently establish a relationship.

The report includes:

* **Tenant Governance:** inbound relationships that are not terminated, with any pending termination flagged, policy roles, provisioned applications, creation time and approval information where available.
* **GDAP and informational CSP partners:** GDAP remote groups, visible roles and partner metadata. Legacy DAP roles and partners without GDAP evidence are explicitly informational.
* **Service providers in cross-tenant access settings:** informational entries only, including former governance tenants with a leftover mark.
* **Related tenants with inbound admin app sign-ins:** optional informational metrics, including activity from allowlisted tenants.

If either the governance-relationship source or the remote-tenant-group source cannot be read, an otherwise passing result becomes **Investigate**. A former governing tenant with remote groups still exposed also needs investigation because the groups' origin cannot be distinguished from GDAP. A leftover service-provider mark or CSP partner record alone does not require investigation. A known unallowlisted in-scope tenant still produces **Failed** even if another source is unavailable.

#### Optional tenant discovery

`IncludeTenantDiscovery` defaults to `true`. Discovery runs only when a **Microsoft Entra ID Governance** service plan is available. If the licence is absent or cannot be confirmed, the discovery request is skipped and the report explains why. The relationship assessment still runs.

Discovery must also be enabled under **Tenant governance** > **Related tenants**. Its **Admin app sign-ins (inbound)** metrics show the number of inbound users and predefined Microsoft administrative applications in the last month, not all B2B collaboration activity. Missing metrics are shown as unavailable, not as evidence of no activity. Discovery failures never change the verdict.

To disable the optional requests:

```json
{
  "TestSettings": [
    { "Id": "MT.1258", "Parameters": { "IncludeTenantDiscovery": false } }
  ]
}
```

The assessment needs `Directory.Read.All`, `TenantGovernance-Relationship.Read.All` and `RemoteTenantGroups.Read.All`. Optional enrichment uses `TenantGovernance-RelatedTenant.Read.All` for discovery, `CrossTenantInformation.ReadBasic.All` for tenant names, `Policy.Read.All` for service-provider information, `RoleManagement.Read.Directory` (or `RoleManagement.Read.All`) for role details, and `AuditLog.Read.All` for approval history. These scopes are included in `Get-MtGraphScope -IncludePreview`. Unavailable enrichment is reported without changing the assessment.

#### Remediation action

1. For each unallowlisted **GDAP partner or governing tenant**, confirm whether it should administer your tenant. Add its tenant ID to `DelegatedAdminTenants` only if approved.
2. For **Tenant Governance**, open the [Microsoft Entra admin center](https://entra.microsoft.com), then **Tenant governance** > **Governing tenants**. Review granted roles and provisioned applications. Terminate unnecessary relationships where the policy permits, or ask the governing tenant to terminate them.
3. For **GDAP**, open [Partner relationships](https://go.microsoft.com/fwlink/p/?linkid=2074649) in the Microsoft 365 admin center under **Settings**. Review each relationship's roles and expiration; remove unnecessary delegated access or ask the partner to reduce privileges.
4. For an **Investigate** result, restore access to unreadable assessment sources or verify the former governing tenant's relationship on the Partner relationships page, then rerun the check.

Legacy DAP and stale service-provider configurations warrant a separate review, but are not failures of this GDAP/Tenant Governance check. Treat reports as confidential: they contain administrative relationships, role details, partner contacts and activity metrics.

#### Related links

* [Governance relationships in Microsoft Entra Tenant Governance](https://learn.microsoft.com/entra/id-governance/tenant-governance/governance-relationships)
* [Introduction to granular delegated admin privileges (GDAP)](https://learn.microsoft.com/partner-center/customers/gdap-introduction)
* [Customer-led removal of a GDAP relationship](https://learn.microsoft.com/partner-center/customers/gdap-customer-terminate)
* [Microsoft Graph remote tenant groups](https://learn.microsoft.com/graph/api/resources/remotetenantgroup?view=graph-rest-beta)
* [GDAP FAQ for customers: GDAP service principals in the customer tenant](https://learn.microsoft.com/partner-center/customers/gdap-migration-faq#what-are-the-two-microsoft-entra-gdap-service-principals-that-are-created-in-the-customer-s-tenant-)
* [Signals and metrics for tenant discovery](https://learn.microsoft.com/entra/id-governance/tenant-governance/signals-metrics)

<!--- Results --->
%TestResult%
