# NewAPI iOS Admin App Design

## Goal

Build a native SwiftUI iPhone app for administering a deployed NewAPI server. The first version focuses on mobile-friendly administrator workflows: connecting to a server, managing channels, model pricing, group ratios, users, and redemption codes.

The app uses NewAPI's existing HTTP API. It does not require server-side code changes.

## Scope

Included in the first version:

- Server connection screen with server URL, administrator username, and password.
- Smart administrator login that rejects ordinary users.
- Single visible server profile, with local data structures prepared for future multi-server support.
- Dashboard with connection status and key counts.
- Channel list, search, details, edit, test, balance update, enable/disable, and delete.
- Pricing management for model pricing, model ratios, and group ratios.
- User list, search, create, edit, enable/disable, delete, group changes, and quota changes.
- Redemption code list, search, create, edit, delete, and clear invalid codes.
- Settings screen for current server, re-login, logout, and local data cleanup.

Not included in the first version:

- Ordinary user features.
- Full OAuth, Passkey, or 2FA login flows.
- WebView wrapping of the existing admin UI.
- NewAPI server modifications.
- Full coverage of every NewAPI system setting.
- App Store release work.

## Architecture

The app is a native SwiftUI application with a small layered structure:

- `NewAPIClient`: owns base URL, request creation, response decoding, cookie persistence, and NewAPI error handling.
- `SessionStore`: owns the active `ServerProfile`, logged-in administrator information, session state, and revalidation.
- Feature services: `ChannelService`, `PricingService`, `UserService`, and `RedemptionService` wrap endpoint-specific calls.
- SwiftUI feature screens consume observable view models rather than calling HTTP APIs directly.

The app should keep implementation minimal. Shared helpers are introduced only for repeated API and form behavior.

## Local Data

`ServerProfile` is stored with fields prepared for future multi-server support:

- `id`
- `name`
- `baseURL`
- `lastUser`
- `lastConnectedAt`

Sensitive data is stored in Keychain:

- Password only if the user chooses to remember it.
- Session/cookie data where needed for persistent login.

Non-sensitive preferences are stored in `UserDefaults`:

- Last server URL.
- Last selected filters.
- Lightweight UI preferences.

## Authentication And Permissions

Login flow:

1. User enters server URL, username, and password.
2. App calls `GET /api/status` to check reachability.
3. App calls `POST /api/user/login`.
4. If NewAPI requires 2FA, the app shows a message explaining that the first version does not support 2FA login.
5. If login succeeds, app checks `role` from the response.
6. If `role < 10`, app calls `GET /api/user/logout`, clears local session data, and displays: "This account is not an administrator and cannot use the mobile admin app."
7. If `role >= 10`, app saves the session and enters the dashboard.

Permission rules:

- Ordinary users cannot log in.
- Admin users can use channels, users, and redemption codes.
- Root-only features, especially option writes under `/api/option/`, show a clear permission message if the server rejects the request.

## Navigation

The app uses a bottom tab bar after login:

- Dashboard
- Channels
- Pricing
- Users
- Redemption Codes
- Settings

Each management tab uses an iPhone-friendly list-detail flow. Lists use cards rather than wide tables. Destructive actions require confirmation.

## Dashboard

Dashboard shows:

- Current server address.
- Current administrator username.
- Connection status.
- Channel count.
- User count.
- Redemption code count.
- Quick links to the main management modules.

Counts are loaded independently. Failure in one card does not block the whole dashboard.

## Channels

Channel screen supports:

- Paginated list from `GET /api/channel/`.
- Search from `GET /api/channel/search`.
- Status and group filters when supported by existing query parameters.
- Detail fetch from `GET /api/channel/:id`.
- Create through `POST /api/channel/`.
- Edit through `PUT /api/channel/`.
- Delete through `DELETE /api/channel/:id`.
- Test through `GET /api/channel/test/:id`.
- Balance update through `GET /api/channel/update_balance/:id`.

Channel cards show name, type, group, status, balance, response time, priority, and weight.

## Pricing And Group Ratios

Pricing reads options from `GET /api/option/` and maps the option array into a dictionary.

The first version includes three sections:

- Model pricing.
- Model ratios.
- Group ratios.

Primary option keys:

- `ModelPrice`
- `ModelRatio`
- `CompletionRatio`
- `CacheRatio`
- `CreateCacheRatio`
- `ImageRatio`
- `AudioRatio`
- `AudioCompletionRatio`
- `GroupRatio`
- `UserUsableGroups`
- `GroupGroupRatio`
- `AutoGroups`
- `DefaultUseAutoGroup`

The app should provide visual editing first. Raw JSON editing is available as an advanced fallback with validation before save.

Model-pricing-related options should use `PUT /api/option/batch` when possible to avoid partial saves. Other options can use `PUT /api/option/` per key.

## Users

User screen supports:

- Paginated list from `GET /api/user/`.
- Search from `GET /api/user/search`.
- Detail fetch from `GET /api/user/:id`.
- Create through `POST /api/user/`.
- Edit through `PUT /api/user/`.
- Role/status actions through `POST /api/user/manage`.
- Delete through `DELETE /api/user/:id`.

User cards show username, display name, group, quota/balance, status, and role.

## Redemption Codes

Redemption code screen supports:

- Paginated list from `GET /api/redemption/`.
- Search from `GET /api/redemption/search`.
- Detail fetch from `GET /api/redemption/:id`.
- Create through `POST /api/redemption/`.
- Edit through `PUT /api/redemption/`.
- Delete through `DELETE /api/redemption/:id`.
- Clear invalid codes through `DELETE /api/redemption/invalid`.

The create flow supports single and batch creation when compatible with NewAPI's existing request fields. Forms include local validation for quota, count, expiry, and usage limits.

## API Response Handling

NewAPI responses are decoded as:

```json
{
  "success": true,
  "message": "",
  "data": {}
}
```

Handling rules:

- `success=false`: show `message`.
- `401` or `403`: show login expired or permission denied, depending on context.
- Network timeout: show server unreachable and preserve local profile.
- Invalid server URL: block login before request.
- Invalid JSON in pricing fields: block save and identify the field.

## Testing Strategy

Automated tests:

- API client response decoding.
- Login success, ordinary user rejection, admin login, Root-only rejection, session expiry, and network timeout.
- Option array to pricing dictionary parsing.
- Form validation for URLs, numeric ratios, prices, quotas, redemption counts, and JSON fields.

Manual tests against the deployed NewAPI server:

- Login with admin account.
- Attempt login with ordinary user account and verify rejection.
- Refresh dashboard.
- Edit a channel and test it.
- Update group ratios.
- Create and delete a redemption code.
- Disable and re-enable a user.
- Logout and re-login.

## Implementation Boundary

The first implementation should prioritize correctness and stability over feature completeness. If an existing NewAPI endpoint has complex or unsafe fields, the app should start with read-only display or advanced JSON editing rather than guessing server behavior.
