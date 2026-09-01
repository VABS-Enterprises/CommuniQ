# Archived level-data drafts

The files in this folder are **superseded drafts** of CommuniQ's learning-level
data and the ad-hoc scripts used to generate them. They are kept for
historical reference only — none of them are read by the running app.

**The canonical, live level-data source is `communiq_levels_1_20.json` at the
repository root**, which is what `client/lib/core/data/static_levels.dart`
is generated from (see that file's header comment) and what ships in the app.

## What's here

- `communiq_levels.json`, `communiq_levels_v3.json`, `communiq_levels_v4.json`
  — earlier/alternate iterations of the level-data JSON, not the version
  actually consumed by the client.
- `gen_v5.py`, `j1.py` – `j9.py` — earlier generator/content scripts used to
  produce level data drafts during content development. Superseded by
  whatever process produced `communiq_levels_1_20.json`.

If you need to regenerate or extend live level data, start from
`communiq_levels_1_20.json` and `client/lib/core/data/static_levels.dart`,
not the files in this folder.
