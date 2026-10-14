# MoonPress social preview

[Download the repository social preview](assets/social-preview.jpg).

The artwork is 1774 × 887 pixels (2:1), opaque RGB JPEG, 223,706 bytes. It was
created with the built-in imagegen tool and exported to JPEG without changing
dimensions or composition. Both project typography and small-preview legibility
were visually checked. The original PNG was 1,352,649 bytes; the JPEG meets
GitHub's under-1-MB requirement while retaining the same design.

Design reference: the [MoonBit rabbit icon](https://github.com/moonbitlang/moonbit-compiler/blob/main/logo.png)
from the official compiler repository. The MoonPress adaptation combines the
rounded rabbit ears and technical visor with an open book and crescent moon.
It is MoonPress project artwork.

## Repository setting

Committing this file and displaying it in README does not configure social
cards for repository links. GitHub Social preview configuration remains pending
in [#200](https://github.com/furukawa1020/MoonPress/issues/200); public OG/Twitter
image verification is also pending. When authenticated repository settings
access is available, use Settings → General → Social preview → Edit → Upload
an image and choose this JPEG, then verify the resulting shared repository card.
See [GitHub's social preview instructions](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/customizing-your-repositorys-social-media-preview).
GitHub recommends 1280 × 640 for best display; this asset uses the same
2:1 ratio at a larger resolution. No external-platform cache refresh is claimed.

## Generation prompt

```text
Use case: ads-marketing / logo-brand. Create a finished GitHub repository social-preview banner for MoonPress, a native MoonBit static-site compiler. Output a wide 2:1 image, exactly 1280 x 640 pixels if possible, solid opaque background. Reference image is MoonBit's official rabbit icon: use its distinctive rounded M-shaped floppy ears, purple-magenta color, white tech visor, and lunar motif as visual inspiration, but make an original MoonPress adaptation: a sleek simple purple rabbit emblem rising from two open folded page shapes / a crescent, conveying compiling Markdown into published pages. Flat, precise, vector-like graphic with gentle restrained depth; premium open-source developer brand, no noisy textures. Icon takes the left third, large readable wordmark on the right; generous safe margins of 80 pixels all around so sharing crops remain legible. Deep midnight navy background, magenta/violet emblem, icy cyan small accents, white typography. Exact text only: 'MoonPress' in large modern bold sans-serif, and below it 'Native MoonBit static-site compiler' in smaller clean sans-serif. No additional copy, no GitHub/X logos, no watermarks, no code screenshots, no UI frames. Avoid copying the reference word/numbers in the visor; use a simple page/angle-bracket motif instead. Keep typography accurate and aligned, strong contrast and clean silhouette. This is the user's MoonPress project graphic, not an official MoonBit announcement.
```
