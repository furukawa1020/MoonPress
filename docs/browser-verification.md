# Browser verification record

## Native administration, 2026-10-22

The real Chrome journey passed on Ubuntu 22.04 and 24.04 in
[CI run 39714277986](https://github.com/furukawa1020/MoonPress/actions/runs/39714277986).
The version including authoring-stage rescue also passed on both platforms in
[CI run 39714307873](https://github.com/furukawa1020/MoonPress/actions/runs/39714307873).
The browser and native admin ran on the same host over loopback. Chrome 155 was
used with page JavaScript disabled. `scripts/browser-test.py` uses Python's
standard library and W3C WebDriver commands, without application JavaScript,
Node/npm, or custom injected browser scripts.

Verified interactions and independent checks:
- Five rooms reached through links.
- Draft creation, editing, saving and reload with persisted text.
- 390-pixel window layout: editor within the window; Tab focuses Save article.
- Browser file upload with byte equality against the saved image.
- Draft preview on the separate port, including a loaded image.
- Ready transition, production review and production build.
- Actual ZIP download, followed by exact archive/file byte comparison.
- Source change after the review form is displayed: stale build rejected and
  previous output bytes preserved.

This exposed and fixed a real form-submission defect: admin HTML used
`Referrer-Policy: no-referrer`, which made form POST origins null. Admin HTML now
uses `same-origin`; cross-origin referrers remain suppressed, null origins are
still rejected, and the restrictive script CSP is unchanged.

The test records browser version, JSON results, screenshots and failure logs in
`_build/browser-verification`. Run `python3 scripts/browser-test.py` after building
the native executable, with Chrome and a matching ChromeDriver installed.
`MOONPRESS_CHROME`, `MOONPRESS_CHROMEDRIVER`, `MOONPRESS_BROWSER_CLI` and
`MOONPRESS_BROWSER_ARTIFACTS` can select binaries/output. Native candidate
installation jobs also run this journey against the exact unpacked executable.

This establishes tested Chrome functionality, not a full visual/accessibility
study, physical mobile-device testing, every keyboard path or cross-browser
compatibility. The downloaded site still requires its own hosting verification.
Physical power-cut tests and signed stable distribution remain separate gates.
The local assistant execution sandbox denied Chrome's Unix socket; the CI
results above are actual browser evidence, not a claim of local execution.

## Earlier public-site check

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

