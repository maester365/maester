Critical Entra objects should have Hard Deletion Protection enabled.

This test reads the users, groups, applications and service principals listed in the
`HardDeletionProtectedObjects` setting of the Maester config and compares each one with its Hard Deletion
Protection setting in Microsoft Entra. Any listed object that is not protected, is soft deleted, or cannot be found
fails the test. If nothing is listed, or every listed object is protected but other objects in Microsoft Entra
have protection and are not listed, the result is **Investigate**: check whether the list is complete.

Protection limits destructive deletion by a compromised administrator. For seven days after an object is soft
deleted, it cannot be permanently deleted, which gives time to notice and restore it (MITRE T1485 Data
Destruction). After the seven days, permanent deletion is possible again. Soft deletion still removes access, so
for T1531 Account Access Removal the benefit is recovery: the object can be restored while protection holds.

See [Hard Deletion Protection](https://maester.dev/docs/configuration/hard-deletion-protection) for the
configuration format and for suggestions on which objects to list.

#### Remediation action:

For an object with the status **Not protected**, first check that it can be protected. Users and groups
synchronized from on-premises Active Directory and mail-enabled security groups cannot be, and also show as not
protected. Remove them from the config, or protect another object instead. For an object that can be protected:

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com) as at least a **Microsoft Entra Backup Administrator**.
2. Browse to **Backup and recovery** > **Hard deletion protection**.
3. Select **Add protection** and choose one object type.
4. Select the reported objects (up to 20 per operation) and review the permanent-protection warning.
5. Select **Save**.

For an object with the status **Soft deleted**: protection can only be enabled on an active object, so restore the
object first. A restored object keeps protection if it already had it. If it did not, follow the steps above.

* A user or a group: restore it from **Deleted users** or **Deleted groups** in the Microsoft Entra admin center.
* An application: restore it from **App registrations** > **Deleted applications**.
* A service principal: the admin center does not show deleted service principals. If its application registration
  was deleted too, restore the registration from **Deleted applications** first, which also restores its service
  principal. Otherwise restore the service principal with Microsoft Graph,
  `POST https://graph.microsoft.com/v1.0/directory/deletedItems/{id}/restore`, or with
  `Restore-MgDirectoryDeletedItem -DirectoryObjectId <id>`, as at least an Application Administrator or Cloud
  Application Administrator. Use a separate delegated Graph connection that has `Application.ReadWrite.All`, not
  the read-only connection Maester uses. Customers cannot restore a deleted managed identity.

For an object with the status **Not found**: check the `Type` and `Id` in the Maester config. The `Id` is the object
ID, not the application (client) ID or a user principal name. If the object was permanently deleted, remove it from
the config.

Protection is permanent and cannot be removed once enabled.

#### Related links

* [Configure Hard Deletion Protection in Microsoft Entra (preview)](https://learn.microsoft.com/entra/backup/configure-hard-deletion-protection)
* [Restore a soft deleted enterprise application](https://learn.microsoft.com/entra/identity/enterprise-apps/restore-application)

<!--- Results --->
%TestResult%
