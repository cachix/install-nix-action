# Release

As of v31, releases of this action follow Semantic Versioning.

### Publishing a new release

#### Publish the release

Draft [a new release on GitHub](https://github.com/cachix/install-nix-action/releases):

- In `Choose a tag`, create a new tag, like `v31.2.1`, following semver.
- Click `Generate release notes`.
- `Set as the latest release` should be selected automatically.
- Publish release

#### Update the major tag

The major tag, like `v31`, allows downstream users to opt-in to automatic non-breaking updates.

This process follows GitHub's own guidelines:
https://github.com/actions/toolkit/blob/main/docs/action-versioning.md

##### Fetch the latest tags

```
git pull --tags --force
```

##### Move the tag

```
git tag -fa v31
```
```
git push origin v31 --force
```

#### Update the release notes for the major tag

Find the release on GitHub: https://github.com/cachix/install-nix-action/releases

Edit the release and click `Generate release notes`.
Edit the formatting and publish.

