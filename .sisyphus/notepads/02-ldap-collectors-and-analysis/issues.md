# Plan 2: LDAP Collectors & Analysis - Issues

## 2026-09-22T19:10:00 - Verification Baseline

- The full PowerShell suite reached 10,384/10,387 passing after the initial implementation. Two task-local analyzer failures were fixed; the remaining unrelated failure is `ActiveDirectoryProtocol.Tests.ps1` child-domain explicit targeting, which expects `misoule02.local` but currently receives `child.misoule02.local` from pre-existing `Connect-MtAdTarget` behavior.
- Live Active Directory query execution is not available in the Linux workspace, so query behavior is validated through parser, analyzer, contract smoke checks, and module build validation pending fixture/E2E coverage in later plan tasks.

## 2026-09-22T19:22:00 - Final Verification

- Full suite result after review fixes: 10,386/10,387 tests passed. The sole failure remains the pre-existing child-domain expectation in `ActiveDirectoryProtocol.Tests.ps1`; task-local PSScriptAnalyzer failures are resolved.
- Build and `Test-MaesterModuleOutput.ps1` both pass with the final LDAP security-descriptor control and query implementations included.

## 2026-09-22T19:50:00 - Concurrent Worktree Changes

- During final review, another workstream modified `.sisyphus/plans/02-ldap-collectors-and-analysis.md`, public AD collectors/checks, and `powershell/tests/functions/ActiveDirectoryOptIn.Tests.ps1`. Task 6 did not modify or revert those files. Final Task 6 validation was scoped to `powershell/internal/ad/queries/`, `Get-MtAdLdapQueryCatalog.ps1`, `ConvertFrom-MtLdapValue.ps1`, and `Invoke-MtLdapSearch.ps1`.

## 2026-09-22T19:40:00 - Task 14 Verification Note

- The aggregate `powershell/tests/pester.ps1` harness stashes and resets a dirty working tree while running generated-file checks. Its task-local findings were fixed (missing verbose logging and one unused variable), then the harness-created `review-baseline` stash was restored. Use focused Pester/analyzer checks on an uncommitted Task 14 workspace to avoid obscuring in-progress changes.
- The aggregate run reached 10,380/10,387 before fixes; five failures were Task 14 style findings and were resolved. The remaining child-domain targeting failure was already documented as unrelated to Task 14.
