1.2.2 (L1) Ensure sign-in to shared mailboxes is blocked

The intent of the shared mailbox is the only allow delegated access from other mailboxes. An admin could reset the password, or an attacker could potentially gain access to the shared mailbox allowing the direct sign-in to the shared mailbox and subsequently the sending of email from a sender that does not have a unique identity. To prevent this, block sign-in for the account that is associated with the shared mailbox.

#### Remediation action:

Block sign-in to shared mailboxes in the UI:
1. Navigate to Microsoft 365 admin center [https://admin.microsoft.com](https://admin.microsoft.com).
2. Click to expand **Teams & groups** and select **Shared mailboxes**.
3. Take note of all shared mailboxes.
4. Click to expand **Users** and select **Active users**.
5. Select a shared mailbox account to open its properties pane and then select **Block sign-in**.
6. Check the box for Block this user from signing in.
7. Repeat for any additional shared mailboxes.

#### Related links

* [Microsoft 365 Admin Center](https://admin.microsoft.com)
* [CIS Microsoft 365 Foundations Benchmark v5.0.0 - Page 39](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
