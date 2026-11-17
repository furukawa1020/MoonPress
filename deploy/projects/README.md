# MoonPress Projects

This directory is the source of the separately deployed browser editor and publishing service linked from MoonPress on GitHub Pages. The MoonBit compiler and static Pages site build independently.

Build within this directory with Bash and Python 3:

```sh
bash scripts/build.sh
```

The build emits `dist/server/index.js` for Cloudflare Workers. The site requires the `DB` D1 binding, its checked-in Drizzle migrations, and platform-managed ChatGPT sign-in. Deploy the same files from the reviewed revision to the managed MoonPress Projects source checkout. Keep the existing database and apply the checked-in migrations in order. Hosted editor publication uses a separate release from the GitHub Pages website.

Public article URLs are `/p/<site>/<article>`. The site's homepage lists published articles and links its RSS feed at `/p/<site>/rss.xml`. The editor stores drafts separately from their public snapshots. An article restored from Trash returns as a draft and will appear again after its owner publishes it.
