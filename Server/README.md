# CWTCH accounts and private cloud saves

Project: https://supabase.com/dashboard/project/ruyertoyvplpmzqflwdy

## Setup status and remaining launch steps

- The project is created and the owner reports running `supabase/migrations/202610020001_cloud_saves.sql`.
- Live requests from Godot reach Supabase Auth over verified HTTPS. Signed-out table reads and save writes both return permission denied (401).
- The full two-account database regression script is `supabase/tests/cloud_isolation.sql`. Run it in SQL Editor; it rolls back all fixture users and saves. This script has not yet been run against the live project.
- The owner reports setting Site URL and the exact allowed Redirect URL to `https://johnawalkeruk-bot.github.io/Cwtch/club.html`.
- Configure a verified email sender through Supabase Authentication's SMTP settings before public registration. Supabase's built-in sender is restricted and is not a public production mail service. Keep email confirmation enabled. See https://supabase.com/docs/guides/auth/auth-smtp . Never put SMTP credentials or a service-role key in this repository.
- Manually publish the website/game using the existing workflow. The club page must be live before users follow confirmation or recovery links. Nothing was pushed or published by this change.
- Finish acceptance with two real confirmed test accounts: register, confirm email, log in from game and website, upload a garden, download it on a second device, attempt a stale upload, and test password recovery. Authenticated live account/email tests are pending.

## Player workflow

Main menu > ACCOUNT & CLOUD. Register or sign in using email/password.
After each sign-in, choose USE THIS COMPUTER'S GARDEN or USE CLOUD GARDEN.
Each account has one cloud garden. Replacing a cloud garden asks for confirmation.
Downloading validates the snapshot and keeps a timestamped `garden.json.before-cloud-*.json` backup beside the local save before replacement. Select ENTER GARDEN afterwards.
Once connected, the game saves locally every minute and uploads following local saves. Failed or conflicting uploads stop syncing, keep the local garden, and require REVIEW CLOUD / RETRY and an explicit choice. Save-and-quit allows a bounded wait for in-flight requests; local progress remains safe if offline.
Sessions are memory-only; restarting the game or reloading the website requires signing in again. No passwords, refresh tokens, database passwords or privileged keys are stored on disk by the integration.
The website is a private read-only snapshot: coins, animal population, XP, terrain percentages and first visit/residency days. It reflects the most recent upload, not a live simulation. Split-screen players share the garden account and save.

## Architecture

`Game/cloud_config.gd` and `Website/cloud-config.js` contain only the public project URL and publishable key.
`public.cwtch_saves` uses owner-only SELECT RLS. Anonymous roles have no grants. Authenticated roles cannot write the table directly. `cwtch_put_save` uses the authenticated user ID and an atomic expected-revision check. It fixes its search path and rejects unauthenticated, oversize and invalid terrain payloads. No caller-supplied owner ID is accepted. Godot validates additional snapshot structure before applying a download.
Private self-reported stats are not an authoritative economy or anti-cheat leaderboard. Population counts currently visible garden animals, excludes outside visitors and arrival scenery.

## Checks

Run from the development root with APPDATA pointing at a disposable `.local` test profile (never your real player profile):

```
Game/runtime/Godot_v4.6.2-stable_win64_console.exe --headless --path Game --script ../DevTools/tests/check_accounts.gd
Game/runtime/Godot_v4.6.2-stable_win64_console.exe --headless --path Game --script ../DevTools/tests/check_cloud_state.gd
```

The first test creates and replaces a disposable local garden and checks live anonymous denial. The second uses fake server replies to check first-sync selection, conflict pausing and failed account switches. Website test: `node DevTools/tests/test_club.cjs` with Playwright available (or CWTCH_PLAYWRIGHT set to its module path); it uses an isolated headless Edge profile and mocked auth/stats responses. It does not sign up a real user.


## Valley Club profiles and friends

Apply `supabase/migrations/202610020002_valley_club.sql` once in the project's SQL Editor, after migration 001. Deploy the matching game and website together when publishing manually. New registrations now require a username; older clients can still sign in and sync existing saves, but must update before registering.

Names contain 3–20 ASCII letters, digits or underscores. A case-insensitive unique database index is authoritative, including concurrent registrations. The signup trigger atomically reserves the name and stores a generated SVG valley portrait against the account ID. Portraits are procedural vector artwork with no external image service. Existing accounts keep their saves and claim a username in Account & Cloud or on the website. Names are permanent in this version.

Signed-in players can search username prefixes (minimum three characters, up to 20 results). Friendships require recipient acceptance. Either player can remove a friendship; senders can cancel requests and recipients can decline them. Accepting shares a filtered snapshot of garden metrics. Full saves and email addresses remain private. Direct profile/friend table access is revoked; authenticated functions enforce access. Removal prevents subsequent comparisons, but cannot retract information already seen.

Comparisons include coins, XP/level, population, discovered/resident species and visit dates, recorded births/deaths, gardening actions today, crops, harvests, purchases, watered tiles, active simulation minutes, weather/wetness and eight terrain types by percentage, tile count and square metres. The garden is currently 576 m². These are self-reported snapshots, not anti-cheat rankings. Blank metrics mean unavailable data.

Local regression checks: `DevTools/tests/check_social.mjs` runs both migrations in isolated PGlite PostgreSQL and verifies registration, uniqueness, existing accounts, privacy and request/accept/remove. Its optional test runtime is `.local/pglite/package` (npm `@electric-sql/pglite`, tested at 0.5.8); never ship it. `DevTools/tests/check_club_social.cjs` tests mocked accounts in isolated Edge and takes screenshots. No live user is created.

References: https://supabase.com/docs/guides/auth/managing-user-data and https://supabase.com/docs/guides/database/functions . Helpers have empty search paths and qualified table names.


### Website account loading fix

The sign-in form is separate from registration. Existing players use their email and password; new accounts additionally choose a username. `club-start.js` reports module-loading failures and keeps submit buttons disabled until initialization succeeds. Authentication and dashboard errors are handled separately. The publisher includes local ES-module dependencies through `site_dependencies.py`, preventing the missing `garden-metrics.js` deployment that disabled login in v0.1.25. Run `DevTools/test_site_dependencies.py` alongside the browser account tests when editing the publication process. No Supabase migration is required for this fix.
