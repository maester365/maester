# Maester

Maester is a testing framework that helps you define and run tests on your Microsoft 365 cloud configuration.

## Developer Guide

### Simple debugging

* Set a breakpoint anywhere in the code and hit F5
* The launch.json has been configured to re-load the module and run Invoke-Maester.ps1
* Change the Tag filter in Invoke-Maester.ps1 to run just the tests file you need.

### Manual editing

* Load the PowerShell module. This needs to be done anytime you make changes to the code in src.
  * `Import-Module ./src/Maester.psd1 -Force`
* Run the tests
  * `./tests/Invoke-Maester.ps1`

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft
trademarks or logos is subject to and must follow
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.
