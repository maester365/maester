# Corrections to the upstream ORCA module (https://github.com/cammurray/orca), which
# ./build/orca/Update-OrcaTests.ps1 applies to each file as it reads it from the clone, before it generates anything.
#
# File:    the file's path in the upstream repository, such as 'Checks/check-ORCA180.ps1' or 'orca.psm1'.
# Find:    the exact upstream text to replace. It must still be in the file: when upstream fixes or rewrites the
#          line, the generator stops and names the entry, so delete it then.
# Replace: the corrected text.
# Reason:  why we change it. Send the fix upstream too, so the entry can go.
@{
    Fixups = @(
        @{
            File    = 'Checks/check-ORCA180.ps1'
            Find    = '"https:/aka.ms/orca-atpp-docs-3"'
            Replace = '"https://aka.ms/orca-atpp-docs-3"'
            Reason  = 'Malformed link: one slash after https:.'
        }
    )
}
