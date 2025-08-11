Additional storage providers in Outlook on the web SHOULD be restricted

Rationale: When additional storage providers are enabled, users can connect to third-party cloud storage services directly from Outlook on the web, potentially bypassing your organization's security controls and data protection policies.

#### Remediation action:

1. Connect to Exchange Online:
```powershell
Connect-ExchangeOnline
```

2. List the current OWA mailbox policies:
```powershell
Get-OwaMailboxPolicy | Select-Object Identity, AdditionalStorageProvidersAvailable
```

3. Disable additional storage providers for the default policy:
```powershell
Set-OwaMailboxPolicy -Identity "OwaMailboxPolicy-Default" -AdditionalStorageProvidersAvailable $false
```

4. Verify the setting:
```powershell
(Get-OwaMailboxPolicy -Identity "OwaMailboxPolicy-Default").AdditionalStorageProvidersAvailable
```
The result should be `False`.

#### Related links

* [OWA Mailbox Policy settings in Exchange Online](https://learn.microsoft.com/en-us/exchange/clients-and-mobile-in-exchange-online/outlook-on-the-web/mailbox-policies)
* [CIS Microsoft 365 Benchmark - 1.3.7 (L2) Ensure 'third-party storage services' are restricted in 'Microsoft 365 on the web'](https://www.cisecurity.org/benchmark/microsoft_365)
* [Microsoft Secure Score - Restrict third-party storage services](https://security.microsoft.com/securescore)

<!--- Results --->
%TestResult%