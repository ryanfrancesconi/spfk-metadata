# Contributing to SPFKMetadata

SPFKMetadata serves [ShadowTag](https://spongefork.com/shadowtag/)'s specific metadata workflows first. It's published as a reusable package because the C++/TagLib bridge is genuinely useful in isolation, but **new features are vetted against whether they fit ShadowTag's use cases** — please open an issue before implementing a feature so we can confirm fit before you invest the time. Bug fixes, performance improvements, and additions to existing functionality don't need this preamble; go ahead.

Saying "doesn't fit my use case" to a feature proposal isn't a judgment on the proposal — it's a signal that this package is opinionated toward one application, and code we wouldn't ship is code we can't accept regardless of quality. Talking it through up front saves both sides time.

## Before you start

This package is part of a small graph of related Swift packages:

- **`spfk-metadata-base`** — Pure Swift data types (`TagKey`, `TagData`, `TagProperties`, `MetaAudioFileDescription` shell, marker structs). No C++ dependency. Anything that's a data type lives here.
- **`spfk-metadata`** (this repo) — The ObjC++/C bridge (`SPFKMetadataC`) over TagLib via [`spfk-taglib`](https://github.com/ryanfrancesconi/spfk-taglib), plus the Swift IO layer (`SPFKMetadata`) that exposes load/save on top of the data types.
- **`spfk-metadata-xmp`** — XMP-specific extensions, separate package.

A change that touches the public `TagKey` enum (for example, adding a new tag) is a cross-package change: the case lands in `spfk-metadata-base`, the I/O wiring lands here.

The README is authoritative for the API surface. Read it before proposing changes that overlap existing functionality.

## PR description template

Not required, but three bullets cover most cases:

- **What:** one or two sentences on what the diff changes.
- **Why:** the bug being fixed or the use case being enabled. If a feature, link the issue where fit was discussed.
- **Verified:** which formats/tools you tested round-trips against, and any locale or migration checks performed.

That's it. The diff itself carries the rest.

## How features fit

### Integrate with `TagKey`, don't parallel it

New tag features land as `TagKey` cases (in `spfk-metadata-base`) that flow through the existing `TagProperties` / `MetaAudioFileDescription` machinery. Callers read and write via `description.tag(for: .yourKey)` / `description.set(tag: .yourKey, value: ...)`.

Standalone bridge classes that exist alongside `TagKey` (rather than inside it) are unlikely to land. If a tag's storage doesn't fit the string-keyed `TagData` model (for example, structured frames like POPM or APIC), the precedent is `ID3FrameKey.picture → "APIC"`: the frame ID is enumerated for spec completeness, but actual I/O is bridge-routed and filtered out of the `PropertyMap` dispatch. That pattern is reusable for any structured frame.

### Don't open a second `FileRef` for WAV or FLAC

`WaveFileC` and `FlacFileC` are the canonical single-load/save consolidators for those formats. Any new per-format I/O hooks onto their existing `load` / `save` cycle as a property (matching `tagPicture`, `bextDescription`, etc.), not as a separate path-based call that opens its own `FileRef`. This is a hard rule: an extra file open on the WAV or FLAC paths is a regression even if the rest of the change is correct.

For formats without a dedicated `FileC` wrapper (MP3, M4A, OGG, etc.), routing through `TagLibBridge` or `TagFile` is fine — those paths already open one `FileRef` per save.

## Scope and coordination

### One concern per PR

Bug fixes are bug fixes. Don't bundle in "while I'm here" refactors, new abstractions, or unrelated cleanup. Each of those is a separate PR if it's worth doing at all. A focused diff is easier to review, easier to revert, and easier to bisect later.

### Coordinate sibling PRs

If you have two in-flight PRs touching the same files, name the interaction in the body — at minimum `depends on #N` or `conflicts with #N`. Don't make the reviewer discover the conflict by reading both diffs side by side and noticing one re-introduces the limitation the other was trying to fix.

## Tests and verification

### Round-trip tests for behavior changes

Any change that affects what gets written to or read from a file needs at least one round-trip test (write → save → reload → assert) in `Tests/SPFKMetadataTests/`. Format-spanning changes (like a new tag that maps to several containers) need one round-trip per format family — ID3v2, Xiph, MP4, APE, ASF — not just one fixture.

"Verified manually on real files" in a PR body is appreciated context, but it isn't a substitute for a test. Tests survive into CI; manual verification doesn't.

### Format interop is empirical

De-facto standards in audio metadata are unreliable from memory or from training data. Vendor-specific conventions disagree subtly (POPM byte buckets, FMPS scales, MP4 user-rating storage locations), and getting them wrong produces silently broken round-trips that the test suite alone can't catch. The interop check is the empirical anchor.

If you write to MP4's `rate` atom, confirm Apple Music reads it. If you write a Vorbis comment, confirm Picard or foobar2000 reads it. If you write a POPM frame, confirm Mp3tag shows the rating. State which tools you verified against, by name and version where relevant.

## Audio metadata gotchas

A short list of failure modes specific to this domain that we've hit in past contributions:

### Locale-sensitive C calls

Any code path that formats or parses floats with C library calls — `snprintf("%f", ...)`, `atof`, `strtod`, `scanf("%f", ...)` — honors the current `LC_NUMERIC` and will silently produce comma-decimal output on non-English systems. A FLAC tagged on a German-locale Mac with this kind of code emits `FMPS_RATING=0,800`; the same Mac then reads it back as `0`. The bug is invisible in en-US testing.

Use one of: integer math with explicit decimal formatting (`String(format: "%d.%03d", value/1000, value%1000)`), `String(format:locale: .init(identifier: "en_US_POSIX"))`, or explicit `setlocale(LC_NUMERIC, "C")` save/restore around the format/parse. Integer math is simplest and avoids locale-state entanglement.

### Data migration when storage location changes

If a change moves where data lives on disk — for example, switching FLAC artwork from `XiphComment` `METADATA_BLOCK_PICTURE=…` entries to native FLAC `Picture` metadata blocks — both sides need handling:

- **Read:** Fall back to the old location if the new one is empty, so existing user files don't appear to lose their data.
- **Write:** Remove or migrate old artifacts so the file ends up with the data in exactly one canonical location, not duplicated across both.

A change that doesn't handle this looks correct on freshly created files and silently regresses on every file the previous version of this package wrote.

### Rationale precision in comments and PR bodies

A "why" comment, or a PR-body sentence explaining why existing code works the way it does, should survive a 30-second grep. Don't invent post-hoc justifications for existing code without verifying them. If a Tag-based method is called from somewhere specific for a specific reason, find the call site and read the existing comment before describing what the design intent is — particularly when proposing to leave that code unchanged because of an assumed property of it.

## Working with AI assistants

LLM-assisted contributions are welcome. If you used a model (Claude, GPT, etc.) to draft any non-trivial portion of the diff or the PR body, please note it briefly:

> Drafted with Claude Code; verified the POPM round-trip on real MP3/M4A files and the FMPS_RATING locale behavior on a German-locale VM.

Two reasons this helps:

1. Format-spanning audio metadata code has subtle bugs (locale, vendor conventions, structured-frame edge cases) that LLMs reliably produce because the training data is full of de-facto-standard knowledge without empirical validation. Reviewers know to focus on those failure modes when an AI is in the loop.
2. Reviewers can skip the "did a human actually finish this refactor or did the model leave dangling helpers / unused branches / unverified format claims" detective work and go straight to the substantive review.

The disclosure isn't a gate. It's an honest signal that shifts where the review attention goes.

If your PR is mostly model output, do the self-review pass before opening it: read the diff cold, check the surrounding files for things the model didn't touch but probably should have, and verify any factual claims the model made about format conventions against the actual format spec or a real test file.


