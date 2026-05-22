# iOS Unsigned Build

This repository includes a GitHub Actions workflow that builds an unsigned iOS app artifact.

## Workflow

- Name: `iOS Unsigned App`
- File: `.github/workflows/ios-unsigned-app.yml`
- Trigger: push to `main` or manual `workflow_dispatch`
- Manual input: `configuration`, either `Release` or `Debug`

## Artifacts

The workflow uploads `NewAPIAdmin-unsigned-app` with two files:

- `NewAPIAdmin-unsigned-app.zip`: zipped `.app` bundle.
- `NewAPIAdmin-unsigned.ipa`: unsigned IPA-style package containing `Payload/NewAPIAdmin.app`.

Artifacts are retained for 14 days.

## Important

The IPA is not signed and cannot be installed on an iPhone directly. It is useful for verifying that GitHub can build the iOS app and as input for a later signing step.

To install on a device, sign the app locally with Xcode or use Apple Developer signing assets in CI.
