# Administration languages

Local administration selects Japanese or English from the browser's
`Accept-Language` header, including regional tags and q weights. Unsupported
languages fall back to English. If the header is absent, existing page defaults
are retained (Japanese rooms and English legacy screens).

Use **日本語**, **English**, or **Auto / 自動** above the page content to override
or restore browser selection. The preference is a host-only, HttpOnly,
SameSite=Strict cookie for one year; Auto deletes it. Save edits before switching.
The preference changes no project files. A safe local GET route is retained when
switching; results of POST operations return to the entrance rather than repeat
a write. Cookie preferences apply to all admin ports on the same host.

Publishing rooms, recovery guidance and common navigation/editor/action labels
have authored Japanese/English copies. Compiler diagnostics and advanced legacy
explanations may remain English. Source titles, Markdown, tags, filenames, form
values, command names, output bytes and previews are never machine-translated.
Localization resolves only application-owned markup markers; escaped user text
cannot create those markers. There is no browser JavaScript, external translation
service or locale stored in a project. Every HTML response sends Content-Language
and Vary: Accept-Language, Cookie with Cache-Control: no-store.

The static public tour remains a separate Japanese example; browser language
negotiation belongs to the native local administration server.
