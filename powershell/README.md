## PowerShell Summary

The Maester project is structured to keep the code organized and maintainable. The `powershell` directory holds all PowerShell-related code, with `internal` for internal utilities and `tests` for testing purposes.

## Folder Structure

This directory contains PowerShell-related scripts and modules.

#### assets/
A subdirectory for templates and other related "general" files.

#### internal/
A subdirectory for internal scripts and functions used by the Maester project. These scripts are not meant to be accessed directly by end users.

#### public/
A subdirectory that contains scripts and functions meant to be accessed directly by end users like the Cmdlet **Invoke-Maester**. These scripts provide the main functionality and features of the Maester project.

#### tests/
A subdirectory that contains test scripts. These scripts are used to verify the functionality and reliability of the Maester project.

## Module structure

### Maester.psd1
This is the PowerShell module manifest file for the Maester project. It contains metadata about the module, such as its version, author, and dependencies.

### Maester.psm1
This is the PowerShell module file for the Maester project. It contains the implementation of the functions and cmdlets provided by the Maester module.

The `Maester.psd1` and `Maester.psm1` files at the root define the module's metadata and implementation, respectively.