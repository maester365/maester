Password hash synchronization is enabled for tenants that synchronise identities from an on-premises Active Directory.

Password hash synchronization sends a hash of the on-premises password hash to Microsoft Entra ID. It gives users the same password in the cloud with no dependency on on-premises servers at sign-in, and it enables Microsoft Entra ID Protection to detect leaked credentials. It is also a recovery option if federation or pass-through authentication fails.

Cloud-only tenants do not use directory synchronization, so the test is skipped as not applicable. Microsoft Graph reads these settings only with delegated permissions, so the test is also skipped on app-only connections. Tenants that deliberately avoid password hash synchronization can record an exception.

#### Remediation action

1. Sign in to the server that runs Microsoft Entra Connect and open the **Microsoft Entra Connect** wizard.
2. Select **Change user sign-in** and enable **Password Hash Synchronization**, or select **Customize synchronization options** and enable it there.
3. Finish the wizard and wait for the next synchronisation cycle.
4. For Microsoft Entra Cloud Sync, open **Entra ID** > **Entra Connect** > [**Cloud Sync**](https://entra.microsoft.com/#view/Microsoft_AAD_Connect_Provisioning/AzureADConnectMenuBlade/~/CloudSync) and enable password hash synchronization in the configuration.

#### Related links

* [Microsoft Entra admin center - Microsoft Entra Connect](https://entra.microsoft.com/#view/Microsoft_AAD_Connect_Provisioning/AzureADConnectMenuBlade/~/GetStarted)
* [What is password hash synchronization with Microsoft Entra ID](https://learn.microsoft.com/entra/identity/hybrid/connect/whatis-phs)
* [Implement password hash synchronization with Microsoft Entra Connect Sync](https://learn.microsoft.com/entra/identity/hybrid/connect/how-to-connect-password-hash-synchronization)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.1.8.1](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
