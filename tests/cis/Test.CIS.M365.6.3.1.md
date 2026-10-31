The default role assignment policy does not grant users the roles that let them install Outlook add-ins.

An Outlook add-in can read and change mail. A malicious or over-privileged add-in, installed by a user who was persuaded to, gives an attacker access to the mailbox without a password. Restricting installation to administrators lets you review the add-in first. An add-in runs inside Outlook each time it starts (T1137.006), and one that can read mail can collect it through the Exchange APIs for someone else (T1114.002).

The test checks the **My Custom Apps**, **My Marketplace Apps** and **My ReadWriteMailbox Apps** roles in the default role assignment policy, which is the policy CIS audits. Custom role assignment policies are outside this recommendation's audit scope. Users who need an add-in can get one deployed by an administrator through Integrated apps.

#### Remediation action

1. Sign in to the [Exchange admin center](https://admin.exchange.microsoft.com).
2. Go to **Roles** > **User roles** > [**Default Role Assignment Policy**](https://admin.exchange.microsoft.com/#/individualpermissions).
3. Clear **My Custom Apps**, **My Marketplace Apps** and **My ReadWriteMailbox Apps**.
4. Select **Save changes**.

#### Related links

* [Exchange admin center - User roles](https://admin.exchange.microsoft.com/#/individualpermissions)
* [Specify the add-ins that users can install](https://learn.microsoft.com/exchange/clients-and-mobile-in-exchange-online/add-ins-for-outlook/specify-who-can-install-and-manage-add-ins)
* [Manage add-ins in the Microsoft 365 admin center](https://learn.microsoft.com/microsoft-365/admin/manage/manage-deployment-of-add-ins)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 6.3.1](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
