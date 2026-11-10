Critical Entra objects should have Hard Deletion Protection enabled.

This test reads the users, groups, applications and service principals listed in the
`HardDeletionProtectedObjects` setting of the Maester config and compares each one with its Hard Deletion
Protection setting in Microsoft Entra. Any listed object that is not protected, is soft deleted, or cannot be found
fails the test. If nothing is listed, or every listed object is protected but other objects in Microsoft Entra
have protection and are not listed, the result is **Investigate**: check whether the list is complete.

See [Hard Deletion Protection](https://maester.dev/docs/configuration/hard-deletion-protection) for the
configuration format and for suggestions on which objects to list.

#### Remediation action:

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com) as at least a **Microsoft Entra Backup Administrator**.
2. Browse to **Backup and recovery** > **Hard deletion protection**.
3. Select **Add protection** and choose one object type.
4. Select the reported objects (up to 20 per operation) and review the permanent-protection warning.
5. Select **Save**.

Protection is permanent and cannot be removed once enabled.

#### Related links

* [Configure Hard Deletion Protection in Microsoft Entra (preview)](https://learn.microsoft.com/entra/backup/configure-hard-deletion-protection)

<!--- Results --->
%TestResult%
