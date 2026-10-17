Creating shared Bookings pages is limited to selected users, or Microsoft Bookings is turned off for the organisation.

A shared Bookings page publishes a scheduling page on the internet that lets outsiders book time with staff and shows availability. Anyone can create one by default, so pages that disclose staff names and calendars, or that are used for phishing with a trusted Microsoft domain, can appear without IT knowing.

The test passes when Bookings is disabled for the organisation, or when the default Outlook on the web policy no longer lets users create Bookings mailboxes. Selected users can then be given a policy that allows it.

#### Remediation action

1. Sign in to the [Microsoft 365 admin center](https://admin.microsoft.com).
2. Go to **Settings** > **Org settings** > **Services** > [**Bookings**](https://admin.microsoft.com/#/Settings/Services/:/Settings/L1/Bookings).
3. Select **Allow only selected staff to be bookable** and **Require Bookings pages to be created by an administrator**, or clear **Allow Bookings to be turned on**.
4. Select **Save**.

#### Related links

* [Microsoft 365 admin center - Bookings settings](https://admin.microsoft.com/#/Settings/Services/:/Settings/L1/Bookings)
* [Manage Microsoft Bookings in your organization](https://learn.microsoft.com/microsoft-365/bookings/turn-bookings-on-or-off)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 1.3.9](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
