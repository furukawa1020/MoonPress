# Article URL, listing and layout settings

The native `PostSettings`, `post_settings` and `save_post_settings` APIs expose
three existing compiler metadata fields separately from article text:

- `slug`: output URL stem; empty removes the override and uses the source filename.
- `listed`: inclusion in article/tag/archive/RSS lists. False does not make an
  article private: it remains built and publicly reachable by its URL.
- `layout`: named `.html` file under `layouts/`; empty uses root `layout.html`.

The shared version-checked save service protects stale writes and preserves
source permissions. An unchanged settings submission preserves exact source
bytes. Changed settings retain title, description, tags, date, draft state and
Markdown body; line endings are normalized to LF during metadata serialization.

Validation uses the compiler's metadata grammar. Saving does not validate the
whole site or check whether a named layout exists. After URL/layout changes,
validate and preview saved sources: route collisions, incoming links or missing
templates may block a build. A route change is not an automatic redirect. A
successful build updates only compiler-owned outputs; a source save never
changes generated files or deploys the site.
