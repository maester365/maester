# Custom Tests

Place your custom Pester tests in this directory. The file name should end with `.Tests.ps1`.

If you need to customize the default tests, you can copy the tests from the `tests` directory add them here and modify to suit your needs.

You can use the -Path parameter to run just the tests in the Custom folder. For example:

```powershell
Invoke-Maester -Path ./Custom
```
