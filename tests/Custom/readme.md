# Custom Tests

Place your custom Pester tests in this directory.

If you need to customize the default tests, you can copy the tests from the `tests` directory add them here and modify to suit your needs.

To make it easier to filter and run just your tests, add a 'Custom' tag to your tests and then run the tests with the `Invoke-Maester.ps1` script using the `-Tag` parameter.

```powershell
./tests/Invoke-Maester.ps1 -Tag Custom
```
