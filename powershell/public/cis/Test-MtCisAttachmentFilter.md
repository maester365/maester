2.1.2 (L1) Ensure the Common Attachment Types Filter is enabled

The Common Attachment Types Filter lets a user block known and custom malicious file types from being attached to emails.

#### Rationale

Blocking known malicious file types can help prevent malware-infested files from infecting a host.

#### Impact

Blocking common malicious file types should not cause an impact in modern computing environments.

The audit also verifies that the `FileTypes` property contains at least the default list of 53 file types below.

#### Remediation action

To enable the Common Attachment Types Filter:

1. Navigate to [Microsoft 365 Defender](https://security.microsoft.com).
2. Click to expand **Email & collaboration** select **Policies & rules**.
3. On the Policies & rules page select **Threat policies**.
4. Under policies select **Anti-malware** and click on the **Default (Default)** policy.
5. On the Policy page that appears on the right-hand pane scroll to the bottom and click on **Edit protection settings**, check the **Enable the common attachments filter**.
6. If any of the default file types are missing, click **Select file types** and add the missing file types in.
7. Click Save.

##### PowerShell

1. Connect to Exchange Online using `Connect-ExchangeOnline`.
2. Run the following Exchange Online PowerShell command:

```powershell
Set-MalwareFilterPolicy -Identity Default -EnableFileFilter $true
```

3. Use `Set-MalwareFilterPolicy -Identity Default` with the `-FileTypes` parameter to add any missing file types from the default list below. Retrieve the existing list first using `Get-MalwareFilterPolicy` and append any missing file types before updating the policy.

Default extensions:

```text
ani, apk, app, appx, arj, bat, cab, cmd, com, deb, dex, dll, docm, elf, exe,
hta, img, iso, jar, jnlp, kext, lha, lib, library, lnk, lzh, macho, msc, msi,
msix, msp, mst, pif, ppa, ppam, reg, rev, scf, scr, sct, sys, uif, vb, vbe,
vbs, vxd, wsc, wsf, wsh, xll, xz, z, ace
```

>Note: Audit and Remediation guidance may focus on the Default policy however, if a Custom Policy exists in the organization's tenant, then ensure the setting is set as outlined in the highest priority policy listed.

#### Related links

* [Microsoft 365 Defender](https://security.microsoft.com)
* [Get-MalwareFilterPolicy](https://learn.microsoft.com/powershell/module/exchangepowershell/get-malwarefilterpolicy?view=exchange-ps)
* [Configure anti-malware policies for cloud mailboxes](https://learn.microsoft.com/defender-office-365/anti-malware-policies-configure?view=o365-worldwide)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - Page 84](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
