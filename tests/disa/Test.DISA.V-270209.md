The Microsoft Entra sign-in page shows the Standard Mandatory DoD Notice and Consent Banner (DISA Microsoft Entra ID STIG, V-270209, CAT II).

DoD information systems must tell every user, before they sign in, that the system is a U.S. Government system, that use is monitored, and that they consent to the terms. In Microsoft Entra ID the banner goes in the **Sign-in page text** of the default company branding, which appears on the sign-in page of every Microsoft cloud app.

The check reads the sign-in page text and passes when it contains the banner: by default the opening sentence of the full banner, or the short banner ("I've read & consent to terms in IS user agreem't.") that DoD allows where space is limited. The field holds 1,024 characters at most, so the full banner may not fit. To look for a different text, set `AcceptedBannerTexts`.

The banner is a DoD requirement. Outside DoD this test fails by design; leave it out of your runs.

#### Remediation action

1. In the [Microsoft Entra admin center](https://entra.microsoft.com), go to **Entra ID** > **Custom branding** > **[Company branding](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/CompanyBrandingMenuBlade/~/CompanyBranding)**.
2. Edit the **Default sign-in experience** (or select **Customize** if there is none yet).
3. On the **Sign-in form** tab, enter the DoD Notice and Consent Banner in **Sign-in page text**.
4. Select **Review + save**, then **Save**.

#### Related links

* [DISA Microsoft Entra ID STIG: V-270209](https://cyber.trackr.live/stig/Entra_ID/1/2/V-270209)
* [Add company branding to your organization's sign-in page](https://learn.microsoft.com/entra/fundamentals/how-to-customize-branding)

<!--- Results --->
%TestResult%
