# Maester Pack registry

One `<publisher>.json` per publisher in `publishers/`: the publisher's GUID, the GitHub accounts that own the entry
(login and numeric ID) and each of its packs' GUID, ID, code and repository. The first pack to register a code
owns it. How to register: https://maester.dev/docs/packs/registry

`build/packs/Test-MtPackRegistry.ps1` checks that every GUID, pack ID, code and publisher is unique, and
`powershell/tests/general/PackRegistry.Tests.ps1` runs it on every pull request. The packs in `packs/` are
registered in `publishers/maester365.json` with the `Code` and `Guid` of their manifests.
