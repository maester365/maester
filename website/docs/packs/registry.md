---
title: Registering a pack code
sidebar_position: 4
description: Own your pack's code by adding your publisher and pack to the pack registry in the Maester repository.
---

# Registering a pack code

Every test ID of a pack starts with its code, so two packs with the same code can't be installed side by side.
Anyone can use any code that isn't reserved, but the first pack to register a code in the **pack registry** owns
it. Registering is optional and free.

The registry lives in the Maester repository in `pack-registry/publishers/`, with one file per publisher. Each
file records:

- the publisher's GUID, its GitHub user or organisation (the first part of its pack IDs) and its display name;
- the GitHub accounts that own the entry, each with its login and its numeric ID, which stays the same when the
  account is renamed;
- each pack's GUID (the `Guid` in its `maester-pack.json`), its ID, its code and its repository.

```json
{
  "$schema": "https://maester.dev/schemas/maester-pack-registry-1.0.json",
  "Guid": "6f1c2a7e-3b9d-4e0a-9c55-0f2d8b7a1e43",
  "Publisher": "contoso",
  "Name": "Contoso",
  "Owners": [
    { "Login": "contoso-admin", "Id": 1234567 }
  ],
  "Packs": [
    {
      "Guid": "2b8e4d10-7c3f-4a61-8e2d-5a9b0c1f6d72",
      "Id": "contoso.google-workspace",
      "Code": "CNT.GWS",
      "Repository": "https://github.com/contoso/maester-google-workspace"
    }
  ]
}
```

## Registering

1. Give your pack a `Guid` in `maester-pack.json`. `New-MtPack` writes one; for an older pack, make one with
   `[guid]::NewGuid()`.
2. Publish the pack in a public repository, so reviewers can see the code in use.
3. Open a pull request in [maester365/maester](https://github.com/maester365/maester) that adds
   `pack-registry/publishers/<publisher>.json`, or adds your pack to your publisher's file. Find your account's
   numeric ID at `https://api.github.com/users/<login>`.

The build checks the registry on every pull request and fails when:

- a GUID is not a GUID, or is used twice anywhere in the registry;
- two publishers have the same GitHub name or display name;
- a pack ID doesn't start with its publisher, or is registered twice;
- a code is reserved, or is the same as or overlaps a registered code (`CNT` and `CNT.GWS` overlap).

A maintainer then checks that the pull request comes from one of the entry's owners and that the code is in use in
the pack's repository. To change an entry later, open a pull request from one of its owners' accounts.
