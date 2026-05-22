# iOS Unsigned Build

This repository includes a GitHub Actions workflow that builds an unsigned iOS simulator app artifact.

## Workflow

- Name: `iOS Unsigned App`
- File: `.github/workflows/ios-unsigned-app.yml`
- Trigger: push to `main` or manual `workflow_dispatch`
- Manual input: `configuration`, either `Release` or `Debug`

## Artifacts

The workflow uploads `NewAPIAdmin-unsigned-app` with two files:

- `NewAPIAdmin-unsigned-simulator-app.zip`: zipped simulator `.app` bundle.
- `NewAPIAdmin-unsigned-simulator.ipa`: unsigned IPA-style package containing `Payload/NewAPIAdmin.app`.

Artifacts are retained for 14 days.

## Important

The IPA is a simulator build and is not signed. It cannot be installed on an iPhone directly. It is useful for verifying that GitHub can build the iOS app.

To install on a device, build and sign the app locally with Xcode or use Apple Developer signing assets in CI.
