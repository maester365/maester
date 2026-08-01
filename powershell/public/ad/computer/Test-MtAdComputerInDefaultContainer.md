#### Test-MtAdComputerInDefaultContainer

#### Why This Test Matters

Computers located in the default `CN=Computers` container represent a security and management concern:

- **No Group Policy inheritance**: The Computers container is not an OU, so it doesn't support Group Policy inheritance
- **Management gaps**: Computers in the default container may not receive security policies, software updates, or configurations
- **Provisioning issues**: Indicates the domain join process hasn't been customized or automated provisioning is failing
- **Shadow IT**: May represent unauthorized systems joined to the domain

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

- `Test-MtAdComputerOUCount` - Shows the distribution of computers across OUs
- `Test-MtAdComputerPerOUAverage` - Analyzes OU structure effectiveness
