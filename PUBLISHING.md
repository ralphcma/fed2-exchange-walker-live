# Publishing Exchange Walker Live

Exchange Walker Live publishes to the Mudlet package repository with GitHub
Actions OIDC trusted publishing. No personal access token or repository secret
is used.

## Prerequisite

The Mudlet package repository must contain the `exchange-walker-live` entry in
`trusted-publishers.json`, authorizing this repository and the exact workflow
path `.github/workflows/publish.yml`.

The registered destination is `packages/exchange-walker-live.mpackage`. The
first trusted publish renames the historical
`exchange-walker-live-3.0.0-live.mpackage` path and therefore requires a Mudlet
package-repository maintainer to review and merge that one-time rename.

## Release procedure

1. Build and test the release from a clean commit.
2. Verify the package version and SHA-256 digest.
3. Create a draft GitHub release whose tag points at that exact commit.
4. Attach exactly one `.mpackage` asset to the draft release.
5. Publish the release only after the asset is attached.
6. Confirm the `Publish to Mudlet package repository` workflow opens a package
   update pull request.
7. Confirm the package-repository validation checks pass. The first rename
   needs manual maintainer review; later ordinary updates retain the stable
   destination filename.

The workflow sends only the release asset URL plus a short-lived GitHub OIDC
token with audience `https://packages.mudlet.org`. The package repository
downloads and validates the asset, records its provenance, and opens the update
pull request. Publishing the GitHub release does not bypass package-repository
review or validation.

Do not publish a release before its `.mpackage` asset is attached. A release
`published` event is delivered once, and the workflow deliberately fails when
no package asset is present.
