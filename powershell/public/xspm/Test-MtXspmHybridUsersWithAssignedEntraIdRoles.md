Microsoft strongly recommends avoiding the use of synchronized identities to manage Microsoft 365 or Microsoft Entra environments for [protecting against on-premises attacks](https://learn.microsoft.com/en-us/entra/architecture/protect-m365-from-on-premises-attacks).

### How to fix
Create [dedicated privileged users](https://learn.microsoft.com/en-us/microsoft-365/enterprise/protect-your-global-administrator-accounts?view=o365-worldwide) to assign and use Entra ID roles, and remove the previous role assignments for the on-premises accounts.

<!--- Results --->
%TestResult%