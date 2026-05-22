# NewAPI iOS Admin Completion Design

## Goal

Complete the existing SwiftUI NewAPI admin app according to the original first-version design, using a Swift Package as the build and test boundary. The result should replace placeholder management screens with working API-backed features, improve session correctness, and add automated tests for the core behavior.

## Project Shape

The project will use a `Package.swift` manifest instead of an Xcode project. The existing `NewAPIAdmin` source directory becomes the main library target. Tests live in `Tests/NewAPIAdminTests` and are verified with `swift test`.

This shape prioritizes reliable validation of models, API handling, services, view models, and form validation. It does not attempt to hand-author a fragile `.xcodeproj` file.

## Architecture

The app keeps the existing layered structure and fills in the missing boundaries:

- `Core/API`: HTTP client, response decoding, query construction, cookie-capable session use, typed errors, and test URLProtocol support.
- `Core/Storage`: non-sensitive profile storage in `UserDefaults`, sensitive remembered credentials in Keychain.
- `Core/Session`: login, 2FA detection, admin-role rejection, restore-and-revalidate through `/api/user/self`, logout, and local cleanup.
- `Features/*`: each management area owns models, a service, a view model, and SwiftUI views.
- `Shared/UI`: reusable loading, empty, error, permission, and confirmation-oriented views.

SwiftUI screens do not call `NewAPIClient` directly. They use observable view models. Services wrap endpoint-specific HTTP calls and stay free of UI state.

## API Client

`NewAPIClient` will support:

- Configurable base URL.
- `GET`, `POST`, `PUT`, and `DELETE`.
- Query items without encoding them into the path string.
- JSON request bodies.
- NewAPI envelope decoding for `{ success, message, data }`.
- Empty response data where endpoints return no payload.
- Typed errors for invalid URL, unauthorized, forbidden, server message, decoding failure, missing data, timeout, and general network failure.

HTTP `401` maps to login expired. HTTP `403` maps to permission denied. Option write failures surface permission wording suitable for Root-only endpoints.

## Session And Storage

Login flow:

1. Normalize the server URL.
2. Call `GET /api/status`.
3. Call `POST /api/user/login`.
4. If the response indicates `require_2fa`, show a first-version unsupported message.
5. If role is below admin, call `GET /api/user/logout`, clear local state, and show an explicit administrator-only error.
6. If role is admin or Root, save the active profile and enter the authenticated app.

Restore flow:

- Load profile and user metadata from `UserDefaults`.
- Create the API client for the saved profile.
- Call `GET /api/user/self`.
- Keep the session only when the returned user is still an administrator.
- Otherwise clear local session metadata.

Remember-password behavior:

- The login form includes a remember-password toggle.
- Passwords are stored in Keychain only when the user enables that toggle.
- Disabling the toggle removes the saved password for that server/user pair.

## Dashboard

The dashboard shows:

- Current server URL.
- Current administrator username and role.
- Connection status from `GET /api/status`.
- Channel count from `GET /api/channel/?p=1&page_size=1`.
- User count from `GET /api/user/?p=1&page_size=1`.
- Redemption count from `GET /api/redemption/?p=1&page_size=1`.
- Quick links to the main modules.

Each card loads independently. A failed card displays its own error without blocking the other cards.

## Channels

The channels feature includes:

- Paginated list through `GET /api/channel/`.
- Search through `GET /api/channel/search`.
- Detail fetch through `GET /api/channel/:id`.
- Create through `POST /api/channel/`.
- Edit through `PUT /api/channel/`.
- Delete through `DELETE /api/channel/:id`.
- Test through `GET /api/channel/test/:id`.
- Balance update through `GET /api/channel/update_balance/:id`.

Cards show name, type, group, status, balance, response time, priority, and weight when those fields are available. Forms cover safe common fields first and retain advanced or unclear server fields through JSON-backed editing rather than guessing.

Destructive actions require confirmation.

## Users

The users feature includes:

- Paginated list through `GET /api/user/`.
- Search through `GET /api/user/search`.
- Detail fetch through `GET /api/user/:id`.
- Create through `POST /api/user/`.
- Edit through `PUT /api/user/`.
- Role/status actions through `POST /api/user/manage`.
- Delete through `DELETE /api/user/:id`.

Cards show username, display name, group, quota or balance, status, and role. Create/edit forms cover username, display name, password where applicable, group, quota, status, and role. Disable, role-change, and delete actions require confirmation.

## Redemption Codes

The redemptions feature includes:

- Paginated list through `GET /api/redemption/`.
- Search through `GET /api/redemption/search`.
- Detail fetch through `GET /api/redemption/:id`.
- Create through `POST /api/redemption/`.
- Edit through `PUT /api/redemption/`.
- Delete through `DELETE /api/redemption/:id`.
- Clear invalid codes through `DELETE /api/redemption/invalid`.

The create flow supports single-code and batch creation fields when the server accepts them. Local validation blocks invalid quota, count, expiry, and usage-limit values before submission. Delete and clear-invalid actions require confirmation.

## Pricing And Group Ratios

The pricing feature includes:

- Fetch all options through `GET /api/option/`.
- Convert the returned option array into a dictionary.
- Edit these primary keys: `ModelPrice`, `ModelRatio`, `CompletionRatio`, `CacheRatio`, `CreateCacheRatio`, `ImageRatio`, `AudioRatio`, `AudioCompletionRatio`, `GroupRatio`, `UserUsableGroups`, `GroupGroupRatio`, `AutoGroups`, and `DefaultUseAutoGroup`.
- Save model-pricing-related options through `PUT /api/option/batch` when possible.
- Save other options through `PUT /api/option/`.
- Provide lightweight visual key-value editors for model prices and group ratios.
- Provide raw JSON editing as the advanced fallback.
- Validate JSON and numeric values before save.

Permission errors from option writes are displayed as Root permission problems, not generic failures.

## Settings

Settings includes:

- Active server profile and admin user display.
- Revalidate session action.
- Logout action.
- Clear local data action.
- Single-server UI while keeping the existing `ServerProfile` model compatible with future multi-server support.

## Shared UI

Reusable views cover:

- Loading state.
- Empty state.
- Error state with retry where appropriate.
- Permission-denied messaging.
- Simple confirmation patterns for destructive actions.

These views stay small and are introduced only where repeated.

## Testing

Automated tests cover:

- API response decoding and error mapping.
- Query item URL construction.
- Login success.
- Ordinary-user rejection.
- 2FA-required response.
- Invalid credentials or server message.
- Session restore expiry.
- Option array parsing.
- Pricing JSON validation.
- Numeric validation for quotas, redemption counts, and ratios.

Tests use mocked `URLProtocol` behavior so they do not require a live NewAPI server.

## Boundaries

The implementation will not modify the NewAPI server. It will not add OAuth, Passkey, or 2FA login flows. It will not attempt full coverage of every NewAPI option key beyond the first-version pricing and group-ratio scope.

Where endpoint schemas are ambiguous, the app favors safe common fields and JSON-backed editing instead of inventing unsupported form semantics.
