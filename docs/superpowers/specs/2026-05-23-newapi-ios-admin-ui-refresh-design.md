# NewAPI iOS Admin UI Refresh Design

## Goal

Refresh the SwiftUI interface of the NewAPI iOS admin app so it feels lighter, cleaner, and more modern without changing any backend behavior or core workflows.

The new look should keep the current information architecture intact, but make the app feel more polished across login, dashboard, chat, management lists, and settings.

## Scope

Included in this refresh:

- Login screen visual polish.
- Tab container and navigation chrome cleanup.
- Dashboard and statistics list/card treatment.
- Chat composer, message bubbles, and picker sheets.
- Settings, management, and empty/error/loading state styling.
- Shared button, form, list, and status styling.

Not included:

- API changes.
- New features or workflow changes.
- Navigation restructuring.
- New server-side behavior.
- Major content copy rewrites.

## Visual Direction

The app should feel:

- Modern.
- Light and airy.
- Clean, but still professional.
- Subtle rather than flashy.

The design should avoid heavy shadows, strong gradients, or dense visual decoration. The goal is a clean, airy aesthetic with better spacing, hierarchy, and surface contrast.

## Design Principles

1. Keep the existing app structure.
2. Improve hierarchy before adding decoration.
3. Use soft surfaces, gentle borders, and restrained emphasis.
4. Make high-frequency screens easier to scan.
5. Keep destructive and status states obvious.
6. Preserve platform-native behavior where it already works well.

## Shared Visual System

The refresh should introduce a consistent visual language across the app:

- Backgrounds should be light and neutral.
- Primary actions should stay accent-colored, but not visually loud.
- Cards and grouped rows should use subtle fills and thin borders instead of heavy shadows.
- Section headers should feel tighter and more intentional.
- Secondary text should remain quiet but readable.
- Empty, loading, error, and permission states should share the same layout rhythm.

## Screen Treatment

### Login

The login screen should feel like the clearest entry point in the app.

- Add a more polished title area and server context display.
- Make saved server entries read like compact account cards.
- Give form sections more breathing room and a cleaner hierarchy.
- Keep Turnstile and error messaging visually integrated instead of tacked on.
- Make the primary login button stronger without becoming bulky.

### Dashboard And Statistics

These screens should present numbers as a calm data surface rather than a plain list.

- Give metric rows/card-like treatment with consistent icon and value alignment.
- Reduce visual weight in dense sections like model pricing and top usage.
- Use spacing and typography to separate overview, realtime, and ranking sections.
- Keep loading overlays simple and unobtrusive.

### Chat

Chat is the most interactive screen and should feel the most refined.

- Improve the top action bar so key/model controls feel like deliberate chips or compact controls.
- Make the composer read as a single grounded surface with clear attachment and send actions.
- Soften bubble styling while preserving user/assistant distinction.
- Keep message cards readable and mobile-friendly.
- Make sheets for token selection, model selection, history, and memory consistent with the rest of the app.

### Management And Settings

These screens should feel organized and efficient.

- List rows should have stronger alignment and clearer leading icons.
- Important actions should be grouped more cleanly.
- Destructive actions should remain visually distinct.
- Account/server information should feel compact and easy to scan.

### States

Loading, empty, error, and permission states should use the same visual tone.

- Centered icon + title + message layout.
- Subtle color use for secondary messaging.
- A single retry pattern for recoverable errors.
- No oversized or overly decorative illustrations.

## Implementation Boundaries

The refresh should be implemented through targeted SwiftUI styling changes, ideally by reusing and lightly expanding shared UI helpers where repeated patterns already exist.

Preferred constraints:

- Do not change request logic or data flow.
- Do not move feature ownership across modules unless a shared style helper clearly reduces duplication.
- Keep changes local to the current feature views and shared UI helpers.
- Avoid introducing a large design system abstraction unless it is clearly needed.

## Testing Strategy

The implementation should be checked by:

- Building the app successfully.
- Verifying login, dashboard, chat, settings, and management screens still open correctly.
- Checking the main layouts on compact and regular iPhone widths.
- Confirming that buttons, text fields, and list rows still fit without overlap.
- Confirming loading and empty states still render correctly.

## Success Criteria

The refresh is successful if:

- The app looks more modern and lighter at a glance.
- The main screens feel visually unified.
- The UI still behaves like the same app.
- Dense content is easier to scan.
- No feature workflow regresses.
