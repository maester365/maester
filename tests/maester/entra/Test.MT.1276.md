Critical Entra objects should have Hard Deletion Protection enabled.

This test reads the users, groups, applications and service principals listed in the
`HardDeletionProtectedObjects` setting of the Maester config and compares each one with its Hard Deletion
Protection setting in Microsoft Entra. Any listed object that is not protected, is soft deleted, or cannot be found
fails the test. If nothing is listed, or every listed object is protected but other objects in Microsoft Entra
have protection and are not listed, the result is **Investigate**: check whether the list is complete.

Protection limits destructive deletion by a compromised administrator. A protected object stays recoverable for
seven days after it is soft deleted, so an attacker cannot permanently destroy it before someone notices
(MITRE T1485 Data Destruction). Soft deletion still removes access, so for T1531 Account Access Removal the
benefit is recovery: the object can be restored while protection holds.

See [Hard Deletion Protection](https://maester.dev/docs/configuration/hard-deletion-protection) for the
configuration format and for suggestions on which objects to list.

#### Remediation action:

For an object with the status **Not protected**:

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com) as at least a **Microsoft Entra Backup Administrator**.
2. Browse to **Backup and recovery** > **Hard deletion protection**.
3. Select **Add protection** and choose one object type.
4. Select the reported objects (up to 20 per operation) and review the permanent-protection warning.
5. Select **Save**.

For an object with the status **Soft deleted**: protection can only be enabled on an active object. Restore the
object from the deleted items in the Microsoft Entra admin center first. A restored object keeps protection if it
already had it. If it did not, follow the steps above.

For an object with the status **Not found**: check the `Type` and `Id` in the Maester config. The `Id` is the object
ID, not the application (client) ID or a user principal name. If the object was permanently deleted, remove it from
the config.

Protection is permanent and cannot be removed once enabled.

#### Related links

* [Configure Hard Deletion Protection in Microsoft Entra (preview)](https://learn.microsoft.com/entra/backup/configure-hard-deletion-protection)

<!--- Results --->
%TestResult%
