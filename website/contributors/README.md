# Maester contributors

Maester's tests are written and maintained by security experts from the community.
Contribution credit is generated automatically at site build time and surfaced in
two places:

- **[maester.dev/contributors](https://maester.dev/contributors)** — profile cards for every
  contributor with the number of tests they authored and improved.
- **Every test page** — a byline crediting the original author and co-contributors.

## How attribution works

1. `website/scripts/contributors.mjs` walks the full git history (following file
   renames) for each test's source files.
2. The **original author** is the person who made the first commit; everyone else
   who touched the test is credited as a **co-contributor**.
3. Identities are matched to GitHub accounts automatically: GitHub noreply
   addresses resolve directly; other commit emails are resolved once via the
   GitHub API and cached as privacy-preserving hashes in
   [`email-aliases.json`](./email-aliases.json) (machine-maintained — never
   edit it by hand); git author names cover the rest.
4. The result is snapshotted to `website/src/data/contributors.json` (used when CI
   builds from a shallow clone) and rendered into the generated test docs.

Run `npm run generate-test-docs` in `website/` to refresh.

## Make your profile shine ✨

Attribution works with zero setup, but you can enrich your profile card:

- Add yourself to [`contributors.yml`](./contributors.yml) — display name, tagline,
  company, website, and social links (see the header comment for the format).
- **Profile picture**: your GitHub avatar is used by default. To use a different
  photo, drop `<your-github-handle>.png` (or `.jpg`) into
  `website/static/img/contributors/`.
- Commit with an email GitHub can't map to your account (e.g. it isn't added to
  your GitHub profile)? Add it under `emails:` in your entry as a manual
  override — but in almost all cases matching just works without it.

## Fixing attribution

If git history credits the wrong person (e.g. a test was contributed via someone
else's PR), add an override in
[`attribution-overrides.yml`](./attribution-overrides.yml).
