# Asset Workspace

This folder is for non-shipping source and staging assets. Anything here is outside the
Xcode app target unless it is deliberately promoted into `App/Resources`.

## Folders

| Folder | Purpose |
| --- | --- |
| `Marketing/Source` | Original marketing and press source images. Deploy-ready copies live in `LandingPageDeploy`. |
| `Marketing/Cards` | The marketing card set (HTML + rendered PNG pairs; formerly Desktop `lull-marketing`). |
| `Staging/<Toy>` | Generated or QA art grouped by toy before selection, processing, or app integration. |
| `Staging/GlowWindow/Processed` | Processed Window cutouts and calibration candidates. |
| `Staging/Unsorted` | Kept reference images that need a better name or owner before promotion. |
| `Staging/Drops/<batch>` | **Raw generation batches as delivered** (formerly loose Desktop folders), named by date — see its README for the batch index. *Gitignored: organized on disk, not in history.* |
| `Reference/` | Concept frames, playtest phone shots, desktop QA screenshots. *Gitignored.* |

Related, outside this folder: `LandingPageSource/` (editable landing page, formerly
Desktop `lull-landing`; deploy copy stays in `LandingPageDeploy/`) and
`Archive/Backups/` (old manual .zip backups, gitignored — git is the backup now).

## Promotion Path

1. Keep rough generations and QA screenshots in `Assets/Staging`.
2. Process, crop, name, and document the chosen file.
3. Promote final app art into `App/Resources/Assets.xcassets` or the appropriate
   `App/Resources` media folder.
4. Update `Docs/AssetManifest.md` when a promoted asset becomes part of the app.
