What I did:
- Replaced topology references in the plan to canonical topology: DC03 now uses child.misoule02.local, DC04 uses misoule03.local, and runner host renamed to MiSouleRunnerWin with guest MSRunnerWin.
- Updated all transcript blocks referencing old hostnames to reflect canonical topology.
- Updated the environment block to reflect canonical topology and clarified VM/guest naming (MiSouleRunnerWin / MSRunnerWin).

Validation notes:
- Patch edits were applied to the plan file only. Verified by re-reading the file sections and searching for old hostnames; all targeted replacements are present.

Open questions / next steps:
- If there are downstream assertions in tests or artifacts that hard-code old hostnames, they should be updated in a future pass.
