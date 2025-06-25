# ⚠️ New Maester action available

The Maester action `maester365/maester@main` will replaced by a new action at [maester365/maester-action](https://github.com/maester365/maester-action).
Moving to a new action allows us to better document the action in the marketplace and proper versioning of the action.

> [!NOTE]
> For now, the old action `maester365/maester@main` will continue to work (and in fact it will call the new action under the hood), but it will not get any new features or fixes.

## Migrate to new action

In your workflow file, replace the following bit:

```yaml
- name: Run Maester 🔥
  uses: maester365/maester@main # this line needs to change
  with:
    # your parameters here

- name: Run Maester 🔥
  uses: maester365/maester-action@v1.0.1 # to this line
  with:
    # your parameters here
    include_private_tests: true # this will checkout the current repository and was the default behavior of the old action
    # if you used install_prerelease: true you should add this line and remove the old one
    maester_version: preview # pick the exact version of the Maester module you want to use or 'latest' or 'preview'
```
