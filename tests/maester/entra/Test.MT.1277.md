Each user flow must be linked to at least one application

Every Entra External ID user flow should be linked to at least one
application (`conditions.applications.includeApplications`). A user flow
with no linked application cannot be used to sign in and typically indicates
an abandoned or incomplete flow — unused attack surface that should be
cleaned up or completed.

This test lists every user flow that has no linked application so they can
be reviewed and either linked to the correct application(s) or removed.

#### Remediation action

1. In the [Entra admin center](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/CustomAuthenticationExtensionsMenuBlade/~/UserFlows), open **External Identities > User flows**.
2. Select each user flow listed in the results below.
3. Go to **Applications** and add the application(s) that should use this flow.
4. If the flow is no longer needed, delete it instead of linking it.

#### Related links

- [Add an application to a user flow](https://learn.microsoft.com/entra/external-id/customers/how-to-user-flow-add-application)

<!--- Results --->
%TestResult%
