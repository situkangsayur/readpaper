# Contributing to ReadPaper

ReadPaper exists so that a Zotero library kept in git is pleasant to read on a
phone, a tablet and a desktop. If you want to help with that, this page is the
whole process. It is short on purpose.

Contributor-facing files (this one, the README, issue and PR templates) are in
English so that anyone can join in. The design notes in `docs/` are in
Indonesian, because that is the language the project is thought in. Either
language is fine in issues and pull requests.

## Licence and sign-off

ReadPaper is licensed under the **GNU Affero General Public License v3 or
later**. By contributing you agree that your contribution is licensed the same
way.

There is **no CLA**. Instead we use the [Developer Certificate of
Origin](https://developercertificate.org/): add a `Signed-off-by` line to each
commit, which `git` will write for you:

```bash
git commit -s -m "Your message"
```

That line is you saying you wrote the patch, or have the right to submit it.
Nothing more, and no rights are signed over to anyone.

## Before you start

- For anything larger than a bug fix, **open an issue first**. It costs you
  five minutes and can save you a weekend spent on something that was already
  half-built on a branch, or that does not fit the format ReadPaper has to
  write back to.
- Check [`docs/backlog.md`](docs/backlog.md). It lists what is planned, in
  which order, and — more usefully — the constraints that are already known.
- Check [`docs/architecture.md`](docs/architecture.md) for the layer rules and
  the Zotero on-disk format.

## Setting up

```bash
flutter pub get
flutter analyze          # must be clean
flutter test             # must be green
flutter run -d linux     # or -d <your android device>
```

Flutter 3.44 or newer. The Android build targets arm64 only.

## The rule that matters most

**ReadPaper writes into someone's real library.** Files are read and rewritten
in the exact byte layout the `zotero-github-sync` plugin produces: tab indents,
sorted keys, children sorted by Zotero key, `annotationPosition` as a compact
JSON string, whole numbers without a trailing `.0`. A change that alters that
layout turns a one-line edit into a several-hundred-line diff in the user's
repository, and may lose data when Zotero reads it back.

So: if you touch anything under `features/library/data/`, run the round-trip
check against a real clone before you open the PR.

```bash
READPAPER_TEST_REPO=~/.local/share/readpaper/repos/<owner>-<repo> \
  flutter test test/_real_repo_check.dart
```

It re-encodes every item file and compares it byte for byte with what is on
disk. It must report zero differences.

## Pull requests

1. Fork, then branch from `main`. Name it for the change:
   `marker-auto-apply`, `fix-copy-empty-clipboard`.
2. Keep one concern per pull request. Two unrelated fixes are two pull
   requests; they get reviewed, and reverted, independently.
3. Run `dart format --line-length 100 .`, `flutter analyze` and `flutter test`.
   CI runs the same three and will not let a red PR merge.
4. Add a test when you fix a bug. The bug got in because nothing was watching
   that line.
5. Fill in the pull request template. The part that is actually read is **how
   you checked it** — "tested on a Moto Pad, two consecutive swipes, both
   highlights saved" is worth more than a paragraph of description.
6. Link the issue with `Closes #123`.

### Commit messages

Write the subject as what the change does, in the imperative, under ~70
characters. Then a blank line, then *why* — what was wrong, and what you
decided against. The code already says what you did; the message is the only
place the reasoning survives.

Commit messages may be in English or Indonesian. Existing history is mostly
Indonesian; that is not a requirement.

## Reporting a bug

Use the bug template. The three things that actually shorten the hunt:

- **Version and device.** The Profile screen shows the version at the bottom;
  a screenshot of it is ideal. More than one "nothing works" report has turned
  out to be an old APK.
- **What you did, tap by tap.**
- **What you expected, and what happened instead.** A screenshot or screen
  recording beats a description.

If it involves your library, please do not paste private paper contents. The
item key and the shape of the file are enough.

## How work is tracked

Issues carry a `type:` label (bug, feature, docs, chore), an `area:` label
(reader, sync, library, android, desktop, plugins, citation) and, where it
applies, a `phase:` label matching `docs/backlog.md`. The GitHub Project board
has four columns: **Inbox → Ready → In progress → Done**. Anything in Ready is
fair game; say so on the issue before you start so two people do not write the
same patch.
