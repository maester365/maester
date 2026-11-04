The default outbound spam policy sets sensible recipient limits, restricts a user who reaches them, turns on outbound spam notifications and names a notification recipient.

A compromised mailbox is usually used to send phishing or spam to a large number of recipients. Recipient limits stop the burst early, and blocking the user, instead of only alerting, stops the abuse and protects your sending reputation.

The default value of 0 means that the service uses its own limits and is not accepted. Set values at or below 500 external recipients per hour, 1000 internal recipients per hour and 1000 recipients per day, and the action to **Restrict the user from sending mail**. The test checks only the default outbound spam policy, as specified by CIS 2.1.15. It also checks that this policy turns on outbound spam notifications and names at least one notification recipient. It cannot tell whether that mailbox is monitored, so confirm that someone reads its messages. Microsoft recommends the alert policy **User restricted from sending email** for admin notifications, and this outbound policy setting is being deprecated.

#### Remediation action

1. Sign in to the [Microsoft Defender portal](https://security.microsoft.com).
2. Go to **Email & collaboration** > **Policies & rules** > **Threat policies** > [**Anti-spam**](https://security.microsoft.com/antispam) and open the **Anti-spam outbound policy (Default)**.
3. Select **Edit protection settings**.
4. Set **External message limit** to 500 or less, **Internal message limit** to 1000 or less and **Daily message limit** to 1000 or less.
5. Set **Restriction placed on users who reach the message limit** to **Restrict the user from sending mail**. In the **Notifications** section, turn on **Notify these users and groups if a sender is blocked due to sending outbound spam**, add a monitored mailbox, then select **Save**.

#### Related links

* [Microsoft Defender portal - Anti-spam policies](https://security.microsoft.com/antispam)
* [Configure outbound spam filtering in EOP](https://learn.microsoft.com/defender-office-365/outbound-spam-policies-configure)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 2.1.15](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
