## What this changes

<!-- One or two sentences. What was wrong, and what it does now. -->

Closes #

## How I checked it

<!-- The part reviewers actually read. Be concrete:
     - device / platform and app version
     - the exact steps you ran
     - what you saw
     "Moto Pad 60 Neo, 0.1.9: two consecutive swipes in marker mode, both
     highlights saved and survived reopening the paper."  -->

- [ ] `dart format --line-length 100 .`
- [ ] `flutter analyze` clean
- [ ] `flutter test` green
- [ ] Tried it on a real device (say which)

## If this touches `features/library/data/`

ReadPaper rewrites files in a real Zotero library, byte for byte as the
`zotero-github-sync` plugin writes them. Confirm the round-trip is unchanged:

- [ ] `READPAPER_TEST_REPO=... flutter test test/_real_repo_check.dart` reports
      zero differences
- [ ] Not applicable

## Anything a reviewer should push back on

<!-- Shortcuts taken, things you were unsure about, alternatives you rejected.
     Saying so here is not a weakness; it is the fastest way to a good review. -->
