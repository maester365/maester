# Azure DevOps Tests - Preview

With the new Azure DevOps tests we will perform a healthcheck towards your Azure DevOps organization.
The base of the tests will be from https://learn.microsoft.com/en-us/azure/devops/organizations/security/security-overview?view=azure-devops and recommendations/considerations from professionals in the field.

The tests uses the [Adops module](https://github.com/AZDOPS/AZDOPS)
However code review is still on-going to include the new functionality in tests/azdo/adops/ADOPS.psm1 module.
I have generated this module on my own until it's officially released and included in this PR.
The offical release depends on the pull requests;
- https://github.com/AZDOPS/AZDOPS/pull/245
- https://github.com/AZDOPS/AZDOPS/pull/246

I have also built it a bit different, including readmes in markdown format under tests/azdo.
And instead of having each test by itself, it's in a module (Code to compile and test module/functions is not included in this branch, let me know if it should be bundled or how I can adapt to how other test suits are built)