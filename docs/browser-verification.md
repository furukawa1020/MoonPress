# Browser verification record

On 2026-10-21, the cloud Chrome browser opened the deployed MoonPress site at
https://furukawa1020.github.io/MoonPress/ (source revision d7b7b7245e97).
The rendered screenshot showed the original rabbit/book logo, pixel typography,
room artwork and entrance link. Accessibility snapshots exposed the main heading,
skip link, navigation and room links. Clicking the entrance and successive room
links reached Writing, Preview and Compiler pages with matching headings and
next/back navigation. This verifies those public static-tour interactions only.

Connecting that browser to the separately hosted local native administration at
127.0.0.1:8080 did not complete: the browser tool timed out. The server was running
locally, but this does not establish connectivity between execution environments.
No administration endpoint was exposed publicly to work around this limitation.

Still required before declaring browser authoring verified:
- Native administration in a browser on the same host: create, edit and save.
- File upload, preview on the second port, reviewed production build and ZIP download.
- Reload/stale-edit behavior, keyboard-only operation and narrow-screen layout.
- Downloaded ZIP inspection and verification on the actual hosting destination.

HTTP integration tests remain separate evidence and do not close these checks.
