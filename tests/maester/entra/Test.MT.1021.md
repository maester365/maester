Security Defaults should be enabled in tenants that are not licensed for Entra ID Premium.

Security Defaults provide a baseline of identity protection, including multifactor authentication registration and enforcement and blocking of legacy authentication, for tenants that cannot use Conditional Access. Tenants with an Entra ID P1 or P2 licence are skipped, because they should configure Conditional Access policies instead.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com) as at least a Conditional Access Administrator.
2. Browse to **Entra ID** > **Overview** > **Properties**.
3. Select **Manage security defaults**.
4. Set **Security defaults** to **Enabled** and select **Save**.

#### Related links

* [Security defaults in Microsoft Entra ID - Microsoft Learn](https://learn.microsoft.com/entra/fundamentals/security-defaults)

<!--- Results --->
%TestResult%
