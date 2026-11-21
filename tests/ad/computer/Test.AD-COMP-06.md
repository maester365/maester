Computers located in the default `CN=Computers` container represent a security and management concern:

- **Limited Group Policy targeting**: The Computers container is not an OU, so GPOs cannot be linked directly to it; applicable domain- and site-linked GPOs can still apply
- **Management gaps**: Computers in the default container may not receive security policies, software updates, or configurations
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

This test fails when an enabled computer is an immediate child of the domain's default `CN=Computers` container. Escaped commas in computer names are handled, and an OU named Computers is not treated as the default container.

#### Related Tests

- `Test-MtAdComputerOUCount` - Shows the distribution of computers across OUs
- `Test-MtAdComputerPerOUAverage` - Analyzes OU structure effectiveness

<!--- Results --->
%TestResult%
