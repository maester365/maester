The default outbound spam policy, and each custom outbound spam policy that an enabled outbound rule applies to, sets sensible recipient limits and restricts a user who reaches them.

A compromised mailbox is usually used to send phishing or spam to a large number of recipients. Recipient limits stop the burst early, and blocking the user, instead of only alerting, stops the abuse and protects your sending reputation.

The default value of 0 means that the service uses its own limits and is not accepted. Set values at or below 500 external recipients per hour, 1000 internal recipients per hour and 1000 recipients per day, and the action to **Restrict the user from sending mail**. The test checks every policy that users receive. A custom policy that no enabled rule applies to is not checked, because no user gets it.

#### Remediation action

1. Sign in to the [Microsoft Defender portal](https://security.microsoft.com).
2. Go to **Email & collaboration** > **Policies & rules** > **Threat policies** > [**Anti-spam**](https://security.microsoft.com/antispam) and open the **Anti-spam outbound policy (Default)**.
3. Select **Edit protection settings**.
4. Set **External message limit** to 500 or less, **Internal message limit** to 1000 or less and **Daily message limit** to 1000 or less.
5. Set **Restriction placed on users who reach the message limit** to **Restrict the user from sending mail**, then select **Save**.
6. Repeat steps 3 to 5 for each custom outbound policy that the test lists.

#### Related links

* [Microsoft Defender portal - Anti-spam policies](https://security.microsoft.com/antispam)
* [Configure outbound spam filtering in EOP](https://learn.microsoft.com/defender-office-365/outbound-spam-policies-configure)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 2.1.15](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
