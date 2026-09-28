# Official Build Components

The files in this folder are **Official Build Components** (DISTRIBUTION-TERMS.md §1(b)).
They are **not** licensed under the Apache License 2.0 (see NOTICE) and are not part of
the Source Code.

* They are copied into the app bundle (`Contents/Resources/Official/`) **only** by the
  official build scripts, which pass `FWARRANGE_OFFICIAL_BUILD=YES` to `xcodebuild`
  (`_tool/fwc-official-components.sh`).
* A build you make yourself from source does not include them and reports
  `"distribution": "Source Build"` in `fWarrangeCli --version`. An Official Build reports
  `"distribution": "Finfra Official Build"`.
* Do not add these files to your own builds or forks — see TRADEMARK.md.
* Next to the banner, the same scripts place copies of `LICENSE`, `NOTICE`, `TRADEMARK.md`,
  `DISTRIBUTION-TERMS.md`, `DISTRIBUTION-TERMS_ko.md` and `COMMERCIAL.md` — the terms are
  presented inside the package (DISTRIBUTION-TERMS §6). Those copies are ordinary repository files.

| File                 | Purpose                                                              |
| :------------------- | :------------------------------------------------------------------- |
| `official-build.txt` | Brand banner. Its first line is the `distribution` value shown above |
