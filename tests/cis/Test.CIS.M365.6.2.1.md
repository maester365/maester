Mail flow rules and outbound spam policies do not forward mail to recipients outside the organisation.

Auto-forwarding is a favourite way to take mail from a compromised mailbox: the attacker adds a rule that copies every message to an outside address and then keeps receiving mail after the password is reset. It is also an easy way for a user to move company data to a personal account.

The test checks the `RedirectMessageTo` property used by the CIS PowerShell audit procedure, and lists enabled transport rules outside audit mode that redirect mail to an address outside the accepted domains. It resolves a recipient stored by alias or name before checking its address. Domain matching is exact: a subdomain is external unless it is itself an accepted domain. It also checks every outbound spam policy returned by Exchange, including custom policies without an enabled rule, and fails if the default policy is missing. Automatic forwarding must be **Off**. The default **Automatic - System-controlled** does not pass, because its effect depends on the organisation.

#### Remediation action

1. Sign in to the [Microsoft Defender portal](https://security.microsoft.com).
2. Go to **Email & collaboration** > **Policies & rules** > **Threat policies** > [**Anti-spam**](https://security.microsoft.com/antispam) and open each outbound policy.
3. Set **Automatic forwarding rules** to **Off - Forwarding is disabled**. Do not use **Automatic - System-controlled**, because its effect depends on how Microsoft applies it in your organisation.
4. Sign in to the [Exchange admin center](https://admin.exchange.microsoft.com).
5. Go to **Mail flow** > [**Rules**](https://admin.exchange.microsoft.com/#/transportrules) and delete or change each rule that redirects mail to an external address.

To turn off automatic forwarding with PowerShell instead of steps 1 to 3, connect with `Connect-ExchangeOnline` and set it on each outbound spam policy, including custom policies without an enabled rule:

```powershell
Set-HostedOutboundSpamFilterPolicy -Identity '<policy name>' -AutoForwardingMode Off

# Or set it on every outbound spam policy at once
Get-HostedOutboundSpamFilterPolicy | Set-HostedOutboundSpamFilterPolicy -AutoForwardingMode Off
```

#### Related links

* [Microsoft Defender portal - Anti-spam policies](https://security.microsoft.com/antispam)
* [Exchange admin center - Mail flow rules](https://admin.exchange.microsoft.com/#/transportrules)
* [Control automatic external email forwarding in Microsoft 365](https://learn.microsoft.com/defender-office-365/outbound-spam-policies-external-email-forwarding)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 6.2.1](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
