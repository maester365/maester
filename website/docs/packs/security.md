---
title: Pack security
sidebar_position: 3
description: What Maester checks before a pack runs, the lock file, the cooldown, the pack policy and the blocklist.
---

# Pack security

A pack runs PowerShell code in your Maester session, with every connection in it, your environment and your
files. Maester is not a sandbox. What it does is make sure that the code that runs is the code you approved, that
you saw what it reaches before approving it, and that your organisation can set limits. Read-only Graph scopes
limit what a pack can change in your tenant; they do not stop it reading local files or sending data out.

## What is checked, and when

| When | Check |
| --- | --- |
| Install | The pack is read without running any of it: manifest, every file, and an AST scan of every script. Errors stop the install. |
| Install | The release is older than the cooldown, the pack policy allows it, and it is not on the blocklist. |
| Install | Its modules are saved at their exact versions into the pack store, and the digest of each module folder is recorded. |
| Install | You approve the prompt. A High risk pack, or one newer than the cooldown, needs its ID typed. |
| Every load | The stored files match the digest in the lock file, the policy still allows the pack, it is not blocked, and every module still matches its digest. Only then is any file loaded. |

Every path that loads pack code goes through that last check: `Invoke-Maester`, `Invoke-MtTest`,
`Connect-Maester`, `Disconnect-Maester`, `Test-MtConnection` and `Get-MtTenantContext`.

## The lock file

`maester-packs.lock.json` pins each pack to a commit and a digest: SHA-256 over the sorted list of every file's
path and SHA-256, with Authenticode signature blocks left out so that signing a pack does not change it. The pack
store keeps the files read-only under that digest. A changed file stops the pack with `PackUnavailable` until
you run `Restore-MtPack` (to get the approved files back) or `Install-MtPack` again (to review the change).

A module that the pack runs in a separate process from your own install (`"Install": "User"`) cannot be pinned:
it is shown as High risk, and `AllowExternalEnvironments: false` refuses the pack.

Each module a pack uses is pinned the same way, by the digest of its folder. A module you installed yourself
(used when the pack policy's `AllowExternalEnvironments` is on) is pinned by its digest at approval, raises the
pack to High risk, and needs approving again when it changes.

## Cooldown

A new release is not installed until it is 72 hours old, so a compromised release has time to be noticed and
blocked. The age comes from the content, never from a date a publisher can set:

- an [immutable release](https://docs.github.com/code-security/supply-chain-security/understanding-your-software-supply-chain/immutable-releases)
  counts from when it was published, because its tag cannot be moved;
- anything else counts from when this computer first saw that commit of that repository, so a tag moved to
  new code starts a new cooldown.

`-IncludeRecent` installs a newer release; at a console you also type the pack's ID. `PackPolicy.CooldownHours`
changes the length.

## Pack policy

The `PackPolicy` section of `maester-config.json`, the `MAESTER_PACK_POLICY` environment variable (a path to a
JSON file) and a machine file (`%ProgramData%\Maester\pack-policy.json` or `/etc/maester/pack-policy.json`) are
combined, and the strictest value of each setting wins:

| Setting | Effect |
| --- | --- |
| `MaximumRisk` | `Low`, `Medium` or `High`: the highest risk a pack may have. |
| `AllowedPublishers` | Only packs from these GitHub owners. |
| `TrustedSources` | Only packs from these sources (`owner/repo`). |
| `AllowUnlisted` | `false`: only packs listed in the Maester Packs index. |
| `RequireBadge` | Only packs with this index badge. |
| `AllowExternalEnvironments` | `false`: a pack may use only modules that Maester saved. |
| `AllowedRuntimes` | The pack runtimes allowed. |
| `CooldownHours` | The cooldown, in hours. |
| `RequireFreshBlocklist` | `true`: no pack runs when the blocklist cannot be fetched. |

Packs that ship with Maester are always allowed.

## Blocklist

Maester fetches a list of blocked packs, signed with an ECDSA P-256 key that ships with the module, and caches it
for an hour. Only a list with a valid signature, a serial at least as high as the last one seen, and an unexpired
date is used. A blocked pack does not install and, when already installed, does not run (`PackBlocked`). When
the list cannot be fetched, the cached list is used with a warning, unless `RequireFreshBlocklist` is set.

## Reporting a pack

Report a malicious or vulnerable pack to the Maester maintainers through
[GitHub security advisories](https://github.com/maester365/maester/security/advisories/new).
