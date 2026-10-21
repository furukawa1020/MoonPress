# Publishing rooms

Open `http://127.0.0.1:8080/rooms` after `moonpress admin SITE 8080`.
The five rooms are a native, server-rendered navigation layer over existing
version-checked editing, draft preview, reviewed building and ZIP export.

- Entrance: current saved inventory and the map.
- Writing: create/edit posts and manage images.
- Preview: existing token-protected draft-inclusive preview build.
- Building: current readiness and existing reviewed-plan form.
- Departure: current readiness; ZIP export appears only when current.

`PublishingRoom` is a closed MoonBit enum. Routes match exact known paths.
GET navigation never writes progress files or marks a room complete. Each view
reads actual saved state; the production rooms revalidate source/output readiness.
Existing POST services recheck tokens, versions and review IDs before mutation.
Back/map navigation stays available when sources are invalid. No artificial XP,
visited flags or completion receipt replaces filesystem checks.

The font and original room artwork are embedded at native build time with
`moon tool embed`. UI asset routes serve only three fixed resources from memory,
never arbitrary paths or source files. CSP allows self-hosted fonts and images;
no scripts or external font requests are required. Standard text inputs keep a
monospace editing font. The pixel font uses SIL OFL; its license is bundled in
the native distribution and public site.

This is a publishing journey, not a new hosting credential manager. Local build,
ZIP download, host deployment and public verification are distinct. Departure
always labels hosting unverified; it cannot upload or check remote deployment.
The public website offers a static room tour and directs users to the local
editor. Actual browser/assistive-technology testing remains outstanding.

The building room is now presented as the bookbinding room (製本室); its route
remains `/rooms/build`. The original project logo is a third fixed embedded
asset. Room descriptions and controls use open typography rather than panels.
