If Microsoft Authenticator is enabled, it SHALL show login context information with Authenticator OTP disabled.

Rationale: This policy helps protect the tenant when Microsoft Authenticator is used by showing user context information, which helps reduce MFA phishing compromises.

The SCuBA MS.AAD.3.3v2 implementation instructions also require **Allow use of Microsoft Authenticator OTP** to be **No**, and ScubaGear checks `isSoftwareOathEnabled = false`. Authenticator software OATH codes do not display the application and location context shown in push and passwordless notifications, so leaving this option enabled fails this check even when both context settings are enabled.

This is **Microsoft Authenticator software OTP**, not **Email OTP** or the separate **Software OATH tokens** authentication method. Email OTP is assessed separately by `CISA.MS.AAD.3.5`; this check does not assess its state.

The check is not applicable when the Microsoft Authenticator policy is absent or disabled, or when an enabled phishing-resistant MFA policy covers all users and applications without exclusions.

#### Remediation action:

If Microsoft Authenticator is in use, configure Authenticator to display context information to users when they log in.

1. In Entra ID, click Security > [Authentication Methods](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods/fromNav/Identity) > **Microsoft Authenticator**.
2. Click the **Configure tab**.
3. For **Allow use of Microsoft Authenticator OTP** select **No**.
4. Under Show application name in push and passwordless notifications select Status > **Enabled** and Target > Include > **All users**.
5. Under Show geographic location in push and passwordless notifications select Status > **Enabled** and Target > Include > **All users**.
6. Select **Save**.

#### Related links

* [CISA Strong Authentication & Secure Registration - MS.AAD.3.3v2](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/aad.md#msaad33v2)
* [CISA ScubaGear Rego Reference](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/AADConfig.rego#L254)

<!--- Results --->
%TestResult%
