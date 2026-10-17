The default Microsoft Intune enrollment restriction blocks personally owned devices, or blocks the whole platform, for every device platform.

Personally owned devices are not under your control: they can carry malware, lack encryption or a screen lock and mix business and private data. When anyone can enrol one, it receives the same trust as a corporate device and can be used to reach company data.

Blocking personal enrolment by default means only devices that IT has marked as corporate can enrol. Add exceptions through higher-priority restrictions assigned to specific groups, for example a bring-your-own-device pilot, rather than by opening the default.

#### Remediation action

1. Sign in to the [Microsoft Intune admin center](https://intune.microsoft.com).
2. Go to **Devices** > **Enrollment** > **Device platform restriction** and open the **Device type restrictions** tab.
3. Select the **All Users** default restriction and then **Properties** > **Edit** next to **Platform settings**.
4. For every platform, set **Personally owned** to **Block** (or block the platform if you do not support it).
5. Select **Review + save**.

#### Related links

* [Microsoft Intune admin center - Enrollment restrictions](https://intune.microsoft.com/#view/Microsoft_Intune_Enrollment/EnrollmentRestrictionsMenuBlade/~/overview)
* [Set enrollment restrictions in Microsoft Intune](https://learn.microsoft.com/intune/intune-service/enrollment/enrollment-restrictions-set)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 4.2](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
