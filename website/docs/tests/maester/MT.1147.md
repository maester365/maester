---
title: MT.1147 - Do not sync krbtgt_AzureAD to Entra ID
description: Checks whether a synchronized krbtgt_AzureAD account exists in Entra ID.
slug: /tests/MT.1147
sidebar_class_name: hidden
---

# Do not sync krbtgt_AzureAD to Entra ID

## Description

Checks whether a synchronized `krbtgt_AzureAD` account exists in Entra ID. Microsoft recommends that this sensitive account exist only in Entra ID and be created and managed automatically by Microsoft's cloud services. Synchronizing an on-premises `krbtgt_AzureAD` account to Entra ID weakens the separation between cloud and on-premises identity systems and can increase privilege escalation risk.

## How to fix

Review your Microsoft Entra Connect synchronization scope and remove the on-premises `krbtgt_AzureAD` account from synchronization.

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com) as at least a Hybrid Identity Administrator.
2. Browse to **Identity** > **Hybrid management** > **Microsoft Entra Connect** and review the current synchronization configuration.
3. On the Microsoft Entra Connect server, identify the on-premises `krbtgt_AzureAD` account and exclude it from synchronization, for example by OU filtering or domain filtering.
4. Run a synchronization cycle and confirm the synchronized `krbtgt_AzureAD` account is no longer present in Entra ID.

## Learn more

- [Security considerations for Microsoft Entra Kerberos | Microsoft Learn](https://learn.microsoft.com/en-us/entra/identity/authentication/kerberos#security-considerations)
- [Microsoft Entra Connect Sync: Configure filtering | Microsoft Learn](https://learn.microsoft.com/en-us/entra/identity/hybrid/connect/how-to-connect-sync-configure-filtering)
- [Microsoft Entra admin center - Microsoft Entra Connect](https://entra.microsoft.com/#view/Microsoft_AAD_Connect_Provisioning/AADConnectMenuBlade/~/ConnectSync)
