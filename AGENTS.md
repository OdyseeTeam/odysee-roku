# Odysee Roku App — Agents Guide

This document gives AI and human contributors a concise map of the repo, the app’s core flows, and safe extension points. It’s based on a scan of this codebase and should help you make targeted changes quickly and safely.

## Overview
- Platform: Roku SceneGraph (BrightScript/BrighterScript structure)
- Primary scene: `HomeScene` orchestrates UI, navigation, and task nodes
- Networking: Centralized helpers in `components/generic/network/http.brs`
- Data sources: Odysee APIs for search, content, auth (device flow), and sync
- Config: Runtime constants fetched via a task; defaults in `appConstants.json`

## Repo Map (high‑value paths)
- App entry: `MVP-Roku/source/main.brs` — creates `roSGScreen`, sets globals, starts `HomeScene`.
- Main scene: `MVP-Roku/components/HomeScene.xml` + `HomeScene.brs` — UI, state, observers, tasks, video playback UI.
- Tasks: `MVP-Roku/components/tasks/` — networked work units returning data to the scene via fields.
  - Auth & device flow: `authTask.brs`, `device-flow/`
  - Front page categories: `getChannelIDs.brs`
  - Content assembly: `getSinglePage.brs`, `getChannelPage.brs`
  - Search: `getVideoSearch.brs`, `getChannelSearch.brs`
  - Constants loader: `getConstants.brs`
  - URL resolve: `resolveLBRYURL.brs`
- Networking: `MVP-Roku/components/generic/network/http.brs` — GET/POST (JSON, URL-encoded), redirects, retries, cookies, auth variants, HEAD helpers.
- Parsing & utils: `components/generic/utility/parseLib.brs`, `liveUtils.brs`, `preferenceLib.brs`, `isValid.brs`.
- UI components: `components/ui/` — `PosterItem`, search keyboard/dialog, chat UI shells.
- Manifest: `MVP-Roku/manifest` — app metadata, resolutions.
- Constants (defaults): `appConstants.json` — endpoints and feature flags used by tasks.

## Core Flows
1. App bootstrap
   - `main.brs` sets `m.global.constants` (user agent, frontend URLs) and scene; passes deep links via screen globals.
   - `HomeScene` initializes timers, UI, registries, and attaches task nodes and field observers.
2. Load constants
   - Task `getConstants.brs` fetches `appConstants.json` from GitHub (device-flow branch) with fallbacks for key fields.
3. Build front page
   - `getChannelIDs.brs` reads `FRONTPAGE_URL`, builds category selector data and a map of channel IDs by category.
   - Selecting a category triggers `getSinglePage.brs`, which:
     - Optionally merges livestreams (via `liveUtils.brs`), then
     - Paginates `claim_search` for channels → parses items with `parseVideo` → emits a `ContentNode` grid (rows of 4).
4. Search
   - Video: `getVideoSearch.brs` uses `LIGHTHOUSE_API` to get claim IDs, then `claim_search` to build grid.
   - Channel: `getChannelSearch.brs` uses `LIGHTHOUSE_API` for channels, then `claim_search` to get 1 latest item/channel and `ROOT_API/subscription/sub_count` for follower counts.
5. Playback
   - `resolveLBRYURL.brs` calls `QUERY_API` `get` and `resolve` to derive streaming URL, resolves redirects, sets HLS vs MP4, provides length/metadata; optionally records `file/view` when statistics enabled.
6. Auth & sync (device flow)
   - `authTask.brs` implements Keycloak Device Flow against `ROOT_SSO`:
     - Phase 1: obtain device code + verification URI; Phase 2: poll for token; Phase 3: token refresh.
     - Stores `accessToken`/`refreshToken` and expirations; legacy `authToken` path retained for compatibility.
   - `device-flow/syncLoop.brs` keeps wallet/preferences in sync between SDK (`ROOT_SDK`) and API (`ROOT_API/sync/*`).
   - `device-flow/getpreferencesTask.brs` and `setpreferencesTask.brs` load and write shared preferences (following, blocked, subscriptions) through SDK + API, with pre‑notification to `/subscription/*` routes when appropriate.
   - Reactions: `device-flow/setreactionTask.brs` posts likes/dislikes via `ROOT_API/reaction/react`.

## Networking Patterns
- All HTTP is centralized in `http.brs`:
  - Helpers: `getJSON`, `getRawText`, `postJSON`, `postURLEncoded`, auth variants (`...Authenticated`), `urlExists`, `resolveRedirect`.
  - Behavior: sets `User-Agent` and TLS bundle, retains body on error, enables cookies; normalizes LF, auto‑follows 3xx, retries on 5xx/timeouts by recursion.
  - Cookies are surfaced to the caller via `m.top.cookies`.
- Query APIs
  - `QUERY_API` JSON‑RPC: `claim_search`, `resolve`, `get`.
  - `ROOT_API`: user, reaction, subscription counts, sync set/get, file view.
  - `LIGHTHOUSE_API`: full‑text search.
  - `NEW_LIVE_API`: livestream listing and status.

## State & Persistence
- Roku registries store auth/device‑flow and preferences:
  - `authData` (legacy token + UID), `deviceFlowData` (access/refresh + wallet hashes + wallet data), `preferences`, `searchHistory`.
- `HomeScene.brs` maintains UI state (focused row/item, search layer depth, video overlay state, timers) and wires observers for task node outputs.

## UI & ContentNodes
- Grids are `RowList` of rows of 4 items; item renderer is `ui/PosterItem` which adapts visuals for `video`, `livestream`, or `channel` and shows `videolength`, badges, and follower counts.
- Search uses `MiniKeyboard` plus `LabelList` for history + dialog actions.

## Configuration
- Runtime constants are fetched by `getConstants.brs`; `appConstants.json` provides defaults for:
  - `FRONTPAGE_URL`, `QUERY_API`, `ROOT_API`, `ROOT_SSO`, `SSO_CLIENT`, `ROOT_SDK`, `LIGHTHOUSE_API`, `IMAGE_PROCESSOR`, `CHANNEL_ICON_PROCESSOR`, `NEW_LIVE_API`, etc.
- `manifest` sets `ui_resolutions=fhd`; splash and icons live under `MVP-Roku/images/`.

## Development & Debugging
- VS Code `launch.json` should point `rootDir` to `MVP-Roku`. Do not commit real device IP/password; use placeholders locally.
- Sideloading and debugging steps are documented in `INSTALL.md`.
- Logging: extensive `?` debug prints across tasks (e.g., timings in `getSinglePage.brs`); keep logs concise in production‑oriented changes.

## Extending Safely
- Add a new Task
  1. Create `components/tasks/MyTask.xml` with fields (inputs/outputs) and `.brs` script; set `m.top.functionName` in `Init()`.
  2. Implement network logic using `http.brs`; respect retry patterns and set `m.top.error`/output fields.
  3. In `HomeScene.brs`, create the node, observe its output field(s), and trigger it from UI input/state.
  4. Component creation checklist (avoid runtime "Failed to create roSGNode with type ..."):
     - The XML must exist and live under `MVP-Roku/components/...`.
     - The XML `component name` must EXACTLY match the string passed to `CreateObject("roSGNode", "Name")`.
     - The XML must `<script>` include its `.brs` and any utility scripts it uses.
     - After adding a new XML, RE-SIDELOAD the app so Roku registers the new component.
     - If you still see the error, double-check path/name casing and that the XML is packaged.
- Add a new API call
  - Prefer `postJSON` for JSON‑RPC; `getURLEncoded`/`postURLEncoded` for REST; use auth variants when calling protected endpoints.
  - Add any new base URL or header to `appConstants.json` (and/or the remote constants) and read through `m.global.constants`.
- Build new grids
  - Parse backend items into slim AAs, then into `ContentNode` trees: `content -> row -> item` with 4 items per row; include fields used by `PosterItem`.
- Auth‑dependent features
  - Read tokens from `m.global` or registries initialized by `HomeScene.brs` and `authTask.brs`. Use `getJSONAuthenticated`/`postURLEncoded` with `Authorization: Bearer ...`.

## Error Handling & Gotchas
- Retries
  - Many helpers auto‑retry on 5xx/timeouts. For task loops (search/claim_search), a manual retry cap (often 5) prevents infinite loops.
- Limits
  - Channel lists ≥ 2048 are special‑cased or not yet supported in some paths (noted in comments).
- Data quirks
  - Some claims may be reposts or lack `value.source.media_type` of `video/mp4`; `parseVideo` filters and returns `{}` in such cases.
- Livestreams
  - Live content is fetched separately and merged into the grid; ensure any new category logic accounts for the live merge step.
- Privacy/secrets
  - Never commit real device passwords or tokens; `.vscode/launch.json` should be local‑only.

## Quick Reference (where to look)
- App entry and globals: `MVP-Roku/source/main.brs`
- Scene wiring: `MVP-Roku/components/HomeScene.brs`
- Network utils: `MVP-Roku/components/generic/network/http.brs`
- Content parsing: `MVP-Roku/components/generic/utility/parseLib.brs`, `liveUtils.brs`
- Device flow auth: `MVP-Roku/components/tasks/authTask.brs`
- Sync loop: `MVP-Roku/components/tasks/device-flow/syncLoop.brs`
- Front page categories: `MVP-Roku/components/tasks/getChannelIDs.brs`
- Search: `MVP-Roku/components/tasks/getVideoSearch.brs`, `getChannelSearch.brs`
- Resolve video: `MVP-Roku/components/tasks/resolveLBRYURL.brs`
- Defaults/config: `appConstants.json`

## Future Improvements (not exhaustive)
- Unify duplicate time/length formatting and claim parsing across tasks.
- Harden error surfaces in tasks to standard shapes (`{ success, errorType, ... }`).
- Extract a small “grid builder” util to centralize `ContentNode` assembly.
- Expand >2047 channel handling into batched queries where TODOs note limitations.
- Consider moving constant fetch to startup and caching with a schema/version.

If you need help deciding where a change fits, start from `HomeScene.brs` to find the observer/trigger, then follow the task to its network helpers.

## BrightScript guardrails (avoid recurring compile/runtime errors)

Use these rules when editing `.brs` to avoid common syntax and runtime pitfalls we’ve repeatedly hit:

- Control flow must be multi-line
  - Never write single-line `if ... then ...` with multiple statements. Always expand to:
```brightscript
if condition then
  ' ... statements
else if otherCondition then
  ' ... statements
else
  ' ...
end if
```
  - Never use inline `for each` bodies. Always:
```brightscript
for each item in items
  ' ...
end for
```

- Match all block terminators
  - Every `if/for/while/function/sub` needs a corresponding `end if/end for/end while/end function/end sub` at the correct nesting level.

- Reserved and case-sensitive identifiers
  - Do not use reserved/common identifiers as variables: e.g., use `focusPos` instead of `pos`.
  - Use correct casing for built-ins: `IsValid(...)` (not `isvalid`).

- Do not introduce placeholders from tasks when merging UI
  - Tasks should not pad rows with `itemType="placeholder"`; merging is handled in `HomeScene.brs` via `appendRowsFillingPartial` which fills partial rows using next page data.

- Initialize and guard UI nodes
  - Always `findNode(...)` in `init()` before accessing fields; guard with `IsValid(node)` before setting fields like `visible`.

- Timer usage pattern
  - When adding background refresh timers:
```brightscript
timer = CreateObject("roSGNode", "Timer")
timer.duration = 300
timer.repeat = true
timer.observeField("fire", "handlerName")
m.top.appendChild(timer)
timer.control = "start"
```
  - Avoid overlapping work: in the handler, check task `state <> "run"` before starting.

- Network and API parameter casing
  - Lighthouse queries require exact `claimType` casing. Our URL encoder normalizes this, but new code must not regress key casing.

- Task interfaces and cookies
  - If a task relies on `http.brs` cookies, declare `<field id="cookies" type="roArray"/>` in its XML.

- Redirect/auth semantics
  - Preserve auth headers across redirects in authenticated requests; use the centralized helpers in `components/generic/network/http.brs`.

Following these patterns prevents the recurring compile errors we’ve seen around inline control flow and ensures consistent UI/task wiring.
