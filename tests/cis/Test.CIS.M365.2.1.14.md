No inbound anti-spam policy in Microsoft Defender for Office 365 lists allowed sender domains.

A domain on the allowed list bypasses spam and phishing filtering. Attackers know that and spoof, or compromise, the domains that organisations trust most, such as partners and suppliers. A single allowed domain turns into a path past the filters.

Use tenant allow/block list entries with an expiry, or fix the root cause of the false positive, instead of allowing a whole domain.

#### Remediation action

1. Sign in to the [Microsoft Defender portal](https://security.microsoft.com).
2. Go to **Email & collaboration** > **Policies & rules** > **Threat policies** > [**Anti-spam**](https://security.microsoft.com/antispam).
3. Open each inbound anti-spam policy and select **Edit allowed and blocked senders and domains**.
4. Remove every entry under **Allow domains** and select **Save**.

#### Related links

* [Microsoft Defender portal - Anti-spam policies](https://security.microsoft.com/antispam)
* [Configure anti-spam policies in Microsoft Defender for Office 365](https://learn.microsoft.com/defender-office-365/anti-spam-policies-configure)
* [Create safe sender lists in Microsoft Defender for Office 365](https://learn.microsoft.com/defender-office-365/create-safe-sender-lists-in-office-365)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 2.1.14](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
