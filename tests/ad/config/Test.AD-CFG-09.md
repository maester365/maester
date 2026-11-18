This inventory counts `msSPP-ActivationObject` objects in the AD-based activation configuration container. Activation objects relate to volume licensing; their count by itself does not prove unauthorized changes or compromise.

#### Control Type

**Operational**

#### Security Recommendation

Keep a deployment inventory of expected activation objects and limit changes to authorized administrators. A count change is a review signal, not evidence of compromise.

#### How the Test Works

The test enumerates `msSPP-ActivationObject` objects in the activation container and reports their count. It does not compare the result with an environment baseline or identify who created an object.



#### Remediation action

Review unexpected activation objects against your deployment inventory and change records before removing anything. Investigate permissions and directory audit events if an unauthorized change is suspected.

#### Related links

- [Microsoft: ms-SPP-Activation-Object schema class](https://learn.microsoft.com/windows/win32/adschema/c-msspp-activationobject)

<!--- Results --->
%TestResult%
