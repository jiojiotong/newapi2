# NewAPI iOS Admin App Implementation Plan

## Phase 1: Project Foundation

- Create a native SwiftUI iOS project in the workspace.
- Target recent iOS versions that support modern SwiftUI navigation and async/await.
- Add a simple app entry point with unauthenticated and authenticated states.
- Define the initial folder structure:
  - `App`
  - `Core/API`
  - `Core/Session`
  - `Core/Storage`
  - `Features/Dashboard`
  - `Features/Channels`
  - `Features/Pricing`
  - `Features/Users`
  - `Features/Redemptions`
  - `Features/Settings`
  - `Shared/UI`

## Phase 2: API And Session Core

- Implement `NewAPIClient` with:
  - Configurable `baseURL`.
  - Shared `URLSession` using cookie persistence.
  - JSON request encoding.
  - NewAPI response decoding for `{ success, message, data }`.
  - Typed errors for invalid URL, network failure, unauthorized, forbidden, server message, and decoding failure.
- Implement `ServerProfile` and `AdminUser` models.
- Implement `SessionStore` with:
  - Current profile.
  - Current admin user.
  - Login/logout state.
  - Session validation through `/api/user/self`.
- Implement lightweight persistence:
  - `UserDefaults` for non-sensitive profile metadata.
  - Keychain wrapper for sensitive values if remember-password is enabled.

## Phase 3: Login Flow

- Build `ServerLoginView` with server URL, username, password, remember password, and login button.
- On login:
  - Normalize server URL.
  - Call `GET /api/status`.
  - Call `POST /api/user/login`.
  - Detect `require_2fa` and show unsupported message.
  - Reject `role < 10` by calling `/api/user/logout` and clearing session.
  - Save profile and enter the authenticated app for `role >= 10`.
- Add clear error messages for unreachable server, invalid credentials, non-admin account, and expired session.

## Phase 4: Authenticated Shell

- Build `MainTabView` with tabs:
  - Dashboard
  - Channels
  - Pricing
  - Users
  - Redemptions
  - Settings
- Use `NavigationStack` inside each tab.
- Add shared loading, empty, error, confirmation, and permission views.

## Phase 5: Dashboard

- Implement `DashboardService` calls:
  - `GET /api/status`
  - `GET /api/channel/?p=1&page_size=1`
  - `GET /api/user/?p=1&page_size=1`
  - `GET /api/redemption/?p=1&page_size=1`
- Build dashboard cards for server status, admin user, channel count, user count, and redemption count.
- Load cards independently so one failed count does not fail the whole screen.

## Phase 6: Channels

- Define channel list and detail models using fields already returned by NewAPI.
- Implement `ChannelService`:
  - List.
  - Search.
  - Detail.
  - Create.
  - Update.
  - Delete.
  - Test.
  - Update balance.
- Build channel list with card rows and filters.
- Build channel detail/edit form for safe common fields first.
- Add confirmation before delete.
- Show server messages after test and balance update.

## Phase 7: Users

- Define user list/detail models.
- Implement `UserService`:
  - List.
  - Search.
  - Detail.
  - Create.
  - Update.
  - Manage actions.
  - Delete.
- Build user card list with search and pagination.
- Build create/edit forms for username, display name, password where applicable, group, quota, status, and role where supported.
- Add admin safety confirmations for disable, role changes, and delete.

## Phase 8: Redemptions

- Define redemption code models based on NewAPI response fields.
- Implement `RedemptionService`:
  - List.
  - Search.
  - Detail.
  - Create.
  - Update.
  - Delete.
  - Clear invalid.
- Build redemption card list.
- Build single and batch create flow where existing server fields allow it.
- Add validation for quota, count, expiry, and usage limits.
- Add confirmation before delete and clear invalid.

## Phase 9: Pricing And Group Ratios

- Implement `PricingService`:
  - Fetch all options from `GET /api/option/`.
  - Convert option array to dictionary.
  - Update one option through `PUT /api/option/`.
  - Batch update model-pricing options through `PUT /api/option/batch`.
- Define option editors for:
  - Model pricing.
  - Model ratios.
  - Group ratios.
- Start with JSON-backed editors plus small visual helpers:
  - List rows for key/value model prices.
  - List rows for group/rate pairs.
  - Raw JSON editor for advanced edits.
- Validate JSON and numeric values before save.
- Show Root permission errors clearly when `/api/option/` is rejected.

## Phase 10: Settings

- Show active server profile and admin user.
- Add revalidate session action.
- Add logout action.
- Add clear local data action.
- Keep UI single-server, but keep data structures compatible with adding multiple profiles later.

## Phase 11: Tests And Verification

- Add API client unit tests using mocked `URLProtocol`.
- Test login outcomes:
  - Admin success.
  - Ordinary user rejection.
  - 2FA required.
  - Invalid credentials.
  - Network failure.
  - Session expired.
- Test option parsing and JSON validation.
- Run the app against the deployed NewAPI server and manually verify:
  - Admin login.
  - Ordinary user rejected.
  - Dashboard loads.
  - Channel edit/test works.
  - Group ratio save works for Root account.
  - User disable/enable works.
  - Redemption create/delete works.
  - Logout and re-login work.

## Build Order

1. Project scaffold and authenticated shell.
2. API client and login.
3. Dashboard.
4. Channels.
5. Users.
6. Redemptions.
7. Pricing.
8. Settings polish.
9. Tests and real-server verification.

## Risk Controls

- Keep dangerous actions behind confirmation dialogs.
- Prefer read-only or raw JSON fallback for server fields whose structure is unclear.
- Treat Root-only failures as permission issues, not generic errors.
- Do not store passwords unless the user explicitly enables remember-password.
- Avoid modifying the NewAPI server in the first version.
