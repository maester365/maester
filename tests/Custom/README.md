# Custom Tests

Welcome to the Custom Tests directory! This is where you can create and manage your own Pester tests tailored to your specific needs. If you have tests you'd like to add or modify, this is the place to do it.

### Getting Started

- **Naming Convention**: Make sure your test files end with `.Tests.ps1` for easy identification.
- **Customizing Tests**: If you need to customize the default tests provided elsewhere, simply copy them from the `tests` directory and modify them to suit your requirements.
- **Running Custom Tests**: To execute tests located in this `Custom` directory exclusively, use the `-Path` parameter with `Invoke-Maester`. For example:

   ```powershell
   Invoke-Maester -Path ./Custom
