Computers located in the default `CN=Computers` container represent a security and management concern:

- **No OU-linked Group Policy**: The Computers container is not an OU and cannot receive a direct OU GPO link; site/domain GPOs and filtering may still apply
- **Management gaps**: Computers in the default container may miss intended OU-linked settings, but are not necessarily unprotected
- **Provisioning issues**: Indicates the domain join process hasn't been customized or automated provisioning is failing
- **Shadow IT**: May represent unauthorized systems joined to the domain

#### Control Type

**Detective**

#### Security Recommendation

- Move all computers from the default Computers container into appropriate OUs based on:
  - Geographic location
  - Department or function
  - Security requirements
- Implement a standardized domain join process that places computers in the correct OU
- Use redircmp.exe to redirect new computer accounts to a specific OU
- Regularly audit the default container for new additions

#### How the Test Works

This test identifies enabled computer accounts where the Distinguished Name contains `CN=Computers,` indicating they are in the default Computers container rather than a proper organizational unit.

#### Related Tests

- **AD-COMP-07 — Computer OU count should be retrievable** — `Test-MtAdComputerOUCount` — Inventories parent locations.
- **AD-COMP-08 — Computer per OU average should be retrievable** — `Test-MtAdComputerPerOUAverage` — Reports placement distribution, not policy effectiveness.

#### Related links

- [Microsoft: Group Policy scope](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-scope)

<!--- Results --->
%TestResult%
