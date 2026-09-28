# System.DirectoryServices.Protocols is a separate assembly on .NET Framework (Windows PowerShell 5.1).
# Load it early so internal AD functions that reference these types can be parsed successfully.
Add-Type -AssemblyName System.DirectoryServices.Protocols -ErrorAction SilentlyContinue
