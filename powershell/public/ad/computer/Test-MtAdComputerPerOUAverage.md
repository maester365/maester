#### Test-MtAdComputerPerOUAverage

#### Why This Test Matters

Understanding the distribution density of computers across OUs helps identify:

- **Overloaded OUs**: OUs with too many computers may indicate poor structure or policy bottlenecks
- **Underutilized OUs**: Many OUs with very few computers may indicate unnecessary complexity
- **Policy application issues**: Uneven distribution can lead to inconsistent security policy application
- **Administrative burden**: Poor structure increases management overhead

The average, minimum, and maximum computers per OU provide metrics for assessing organizational efficiency.

#### Security Recommendation

- Aim for a balanced OU structure that:
  - Supports your Group Policy design (each OU should have a clear policy purpose)
  - Enables delegated administration without excessive granularity
  - Can be easily understood and navigated by administrators
- Investigate OUs with unusually high computer counts
- Consider consolidating OUs with very few computers if they serve similar purposes
- Document the OU design rationale for future administrators

#### How the Test Works

This test groups all enabled computers by their parent container and calculates:
- Average computers per OU
- Minimum computers in any OU
- Maximum computers in any OU
- Distribution across the top containers

#### Related Tests

- `Test-MtAdComputerOUCount` - Counts the total number of OUs with computers
- `Test-MtAdComputerInDefaultContainer` - Identifies potential OU structure gaps
