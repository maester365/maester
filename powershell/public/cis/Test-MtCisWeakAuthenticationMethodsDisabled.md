5.2.3.5 (L1) Ensure weak authentication methods are disabled

Authentication methods support a wide variety of scenarios for signing in to Microsoft 365 resources. Some of these methods are inherently more secure than others but require more investment in time to get users enrolled and operational.

SMS and Voice Call rely on telephony carrier communication methods to deliver the authenticating factor.

The recommended state is to Disable these methods:
* SMS
* Voice Call

#### Rationale

Traditional MFA methods such as SMS codes, email-based OTPs, and push notifications are becoming less effective against today’s attackers. Sophisticated phishing campaigns have demonstrated that second factors can be intercepted or spoofed. Attackers now exploit social engineering, man-in-the-middle tactics, and user fatigue (e.g., MFA bombing) to bypass these mechanisms. These risks are amplified in distributed, cloud-first organizations with hybrid workforces and varied device ecosystems.

The SMS and Voice call methods are vulnerable to SIM swapping which could allow an attacker to gain access to your Microsoft 365 account.

#### Impact

There may be increased administrative overhead in adopting more secure authentication methods depending on the maturity of the organization.

#### Remediation action:

1. Navigate to [Microsoft Entra admin center](https://entra.microsoft.com).
2. Click to expand **Entra ID** > **Authentication methods**
3. Select **Policies**.
4. Inspect each method that is out of compliance and remediate:
* Click on the method to open it.
* Change the **Enable** toggle to the off position.
* Click **Save**.

>Note: If the save button remains greyed out after toggling a method off, then first turn it back on and then change the position of the Target selection (all users or select groups). Turn the method off again and save. This was observed to be a bug in the UI at the time this document was published.

##### PowerShell

1. Connect to Graph using `Connect-MgGraph -Scopes "Policy.ReadWrite.AuthenticationMethod"`
2. Run the following to disable these two authentication methods:
```powershell
$params = @(
    @{ Id = "Sms"; State = "disabled" },
    @{ Id = "Voice"; State = "disabled" }
)
Update-MgPolicyAuthenticationMethodPolicy -AuthenticationMethodConfigurations $params
```

#### Related links

* [Microsoft Entra admin center](https://entra.microsoft.com)
* [Manage authentication methods for Microsoft Entra ID](https://learn.microsoft.com/en-us/entra/identity/authentication/concept-authentication-methods-manage)
* [Context and problem](https://learn.microsoft.com/en-us/security/zero-trust/sfi/phishing-resistant-mfa#context-and-problem)
* [What is SIM swapping & how does the hijacking scam work?](https://www.microsoft.com/en-us/microsoft-365-life-hacks/privacy-and-safety/what-is-sim-swapping)
* [CIS Microsoft 365 Foundations Benchmark v6.0.1 - Page 288](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%