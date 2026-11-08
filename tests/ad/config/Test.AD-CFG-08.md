This inventory counts objects under the AD authentication policy configuration container. A container/object count does not show whether an authentication policy is assigned to an account, nor whether any particular policy is effective.

#### Control Type

**Operational**

#### Security Recommendation

Where authentication policies are part of the organization's design, review their scope, assignments and intended restrictions with the AD security owner. Do not equate the presence of policy objects with enforcement.

#### How the Test Works

The test counts objects returned from the authentication policy configuration container. It does not evaluate policy contents, account assignments or effective authentication behavior.



#### Remediation action

Review the policies, policy silos and assignments where your organization uses authentication policies. A zero count alone does not establish a security failure; investigate whether the configuration matches your intended controls.

<!--- Results --->
%TestResult%
