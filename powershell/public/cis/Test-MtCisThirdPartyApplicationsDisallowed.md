5.1.2.2 (L1) Ensure users cannot register applications

This setting controls whether standard users can register applications in the Microsoft Entra ID directory. When enabled, any user can create app registrations, which function as identity objects for applications.

#### Rationale

Allowing standard users to create app registrations expands the tenant's attack surface. A compromised account or malicious insider could create a rogue app registration to establish a persistent OAuth client, facilitate token theft, or impersonate a legitimate application. Restricting app registration to privileged roles ensures that new application identities in the directory are subject to administrative review and approval before they can be granted permissions to organizational resources.

#### Impact

End users will no longer be able to register applications independently, including both third-party integrations and custom applications. Developers and IT staff who create app registrations as part of normal workflows will be affected and will need to submit registration requests to a privileged administrator (e.g., Application Administrator or Cloud Application Administrator). Organizations should establish a formal request and approval process before implementing this change to avoid workflow disruption.

#### Remediation action

1. Navigate to [Microsoft 365 Entra admin center](https://entra.microsoft.com).
2. Click to expand **Entra ID** > **Users** select **Users settings**.
3. Set **Users can register applications** to **No**.
4. Click **Save**.

##### PowerShell

1. Connect to Microsoft Graph using `Connect-MgGraph -Scopes "Policy.ReadWrite.Authorization"`
2. Run the following commands:

```powershell
$param = @{ AllowedToCreateApps = $false }
Update-MgPolicyAuthorizationPolicy -DefaultUserRolePermissions $param
```

#### Related links

* [Microsoft 365 Entra admin center](https://entra.microsoft.com)
* [How and why applications are added to Microsoft Entra ID](https://learn.microsoft.com/entra/identity-platform/how-applications-are-added)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - Page 197](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
