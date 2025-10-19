Ensure soft and hard matching for on-premises synchronization objects is blocked

When you start synchronizing with Microsoft Entra Connect, the Microsoft Entra service API checks every new incoming object and tries to find an existing object to match. There are three attributes used for this process: userPrincipalName, proxyAddresses, and sourceAnchor/immutableID. A match on userPrincipalName or proxyAddresses is known as a "soft-match." A match on sourceAnchor is known as "hard-match." For the proxyAddresses attribute, only the value with SMTP:, that is the primary email address, is used for the evaluation.
Both, the hard-match and soft-match, tries to match objects already present and managed in Microsoft Entra ID with the new incoming objects being added that represent the same on-premises entity. If Microsoft Entra ID isn't able to find a hard-match or soft-match for the incoming object, it provisions a new object in Microsoft Entra ID directory.

The match is only evaluated for new objects coming from on-premises AD. If you change an existing object so it matches any of these attributes, then you see an error instead.

If Microsoft Entra ID finds an object where the attribute values are the same as the new incoming object from Microsoft Entra Connect, then it takes over the object in Microsoft Entra ID and the previously cloud-managed object is converted to on-premises managed. All attributes in Microsoft Entra ID with a value in on-premises AD are overwritten with the respective on-premises value.

Matching existing Entra objects with newly synchronized on-premises active directory objects can lead to unintended consequences, such as mismatching user data or allowing users to access data, of for example colleagues with the same name, they should not have access to.

#### Remediation action:

To block soft- and hard-match from on-premises directory synchronization using Graph PowerShell:
1. Connect to Graph using **Connect-MgGraph -Scopes "OnPremDirectorySynchronization.ReadWrite.All"**.
2. Run following PowerShell Command:
```
$onPremisesSynchronization = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/directory/onPremisesSynchronization" -OutputType PSObject | Select-Object -ExpandProperty value
$params = @{
	features = @{
		BlockCloudObjectTakeoverThroughHardMatchEnabled = $true
        BlockSoftMatchEnabled = $true
	}
}
Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/v1.0/directory/onPremisesSynchronization/$($onPremisesSynchronization.id)" -Body $params
```

#### Related links

* [Microsoft Entra Connect: When you have an existing tenant | Microsoft Learn](https://learn.microsoft.com/en-us/entra/identity/hybrid/connect/how-to-connect-install-existing-tenant)
* [Update-MgDirectoryOnPremiseSynchronization | Microsoft Learn - Graph PowerShell v1.0](https://learn.microsoft.com/de-de/powershell/module/microsoft.graph.identity.directorymanagement/update-mgdirectoryonpremisesynchronization?view=graph-powershell-1.0)

<!--- Results --->
%TestResult%