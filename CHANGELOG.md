# Changelog

## [0.5.1](https://github.com/telip007/stipple/compare/0.5.0...0.5.1) (2026-10-19)


### Bug Fixes

* **render:** make colored backgrounds opaque ([b7a9896](https://github.com/telip007/stipple/commit/b7a98962737368a680206e4a7241263afc2d6a18))


### Documentation

* update examples and demos for the current feature set ([352b6fe](https://github.com/telip007/stipple/commit/352b6fe33d26f796ed4e10d69f29b5456926105b))

## [0.5.0](https://github.com/telip007/stipple/compare/0.4.0...0.5.0) (2026-10-19)


### Features

* add LazyVStack for long scroll content ([f2f714f](https://github.com/telip007/stipple/commit/f2f714f1ce5199d3d0cf301f92a13a85a25a692c))

## [0.4.0](https://github.com/telip007/stipple/compare/0.3.3...0.4.0) (2026-10-19)


### ⚠ BREAKING CHANGES

* EnvironmentValues.terminalSize is @MainActor.

### Performance

* make frames cost what is on screen, not the whole scrollback ([2988731](https://github.com/telip007/stipple/commit/2988731ad7006d112b1e7b4b3ad9da2a25293038))

## [0.3.3](https://github.com/telip007/stipple/compare/0.3.2...0.3.3) (2026-10-19)


### Performance

* resume wrapping growing text and draw typed keys at once ([978bcf3](https://github.com/telip007/stipple/commit/978bcf3d35a832ba921b5ea7d7c7e746646f5c17))


### Documentation

* **wiki:** stop the clock in tests of close events ([e7812d6](https://github.com/telip007/stipple/commit/e7812d60cbb800c32a3eb73c72ae2cf23aa61421))

## [0.3.2](https://github.com/telip007/stipple/compare/0.3.1...0.3.2) (2026-10-18)


### Performance

* **layout:** keep layout work across frames ([c077edb](https://github.com/telip007/stipple/commit/c077edb40d8a549668c4d3582e8c4e2dfec147ff))

## [0.3.1](https://github.com/telip007/stipple/compare/0.3.0...0.3.1) (2026-10-18)


### Bug Fixes

* **text:** keep the last lines under head truncation ([4409051](https://github.com/telip007/stipple/commit/44090510f82234fc268f19d8d8eccef5da7a11e8))

## [0.3.0](https://github.com/telip007/stipple/compare/0.2.0...0.3.0) (2026-10-18)


### Features

* focus on click, hover and clickable SelectionList rows ([4a382c9](https://github.com/telip007/stipple/commit/4a382c9733be83af5e5c29ee1ac69d3147237639))

## [0.2.0](https://github.com/telip007/stipple/compare/0.1.1...0.2.0) (2026-10-18)


### Features

* add ScrollView, ScrollPosition and mouse wheel scrolling ([63a411f](https://github.com/telip007/stipple/commit/63a411f2720d7b46ab77acc29e060b949a9f21d9))

## [0.1.1](https://github.com/telip007/stipple/compare/0.1.0...0.1.1) (2026-10-18)


### Bug Fixes

* **components:** move the TextField caret to the end after outside changes ([4f44fb3](https://github.com/telip007/stipple/commit/4f44fb3325e12f5784e5683777d592ace34dbb81))
* **components:** pass Ctrl-D on an empty TextField to ancestors ([b4c58f4](https://github.com/telip007/stipple/commit/b4c58f4e1c4687658a6f092f873ec41f2f99959d))
* downsample colors to the terminal's color depth ([7f6f0b0](https://github.com/telip007/stipple/commit/7f6f0b0cfa563ad5e219605d0e6602347084769b))

## 0.1.0 (2026-10-18)


### Features

* add Divider, hidden and disabled; fix Swift 6.2 build on Linux ([cc9da32](https://github.com/telip007/stipple/commit/cc9da320201ea581404a69bc2c08fb0786904a8a))
* add screen reader output, overlays, text transforms and terminal suspension ([3ac5416](https://github.com/telip007/stipple/commit/3ac541679f18d2a019174b633e8892a7271af035))
* add the SwiftUI-shaped view system, runtime and examples ([866ad2e](https://github.com/telip007/stipple/commit/866ad2e08d03512bcca3aa562e4fb494f8c1f7f8))
* **components:** add ProgressView and SelectionList ([7189d39](https://github.com/telip007/stipple/commit/7189d39ee9584bb3c743977d109a41ec1d4e97d1))
* **components:** add TextField and SecureField ([00cf07c](https://github.com/telip007/stipple/commit/00cf07c9df9196f1f436f2e73dbb724b10f62713))
* **input:** decode stdin bytes into key, paste and focus events ([ac3e202](https://github.com/telip007/stipple/commit/ac3e2020d4fccd3176ecce3a3c823abb08ec0802))
* **output:** add screen-reader frame mode ([4024def](https://github.com/telip007/stipple/commit/4024defb7e288a78830e4ea9bc8d798482df4560))
* **output:** port Ink's frame writer and log-update ([19329f8](https://github.com/telip007/stipple/commit/19329f80c716955f11d97b3529609bc95de11317))
* **render:** text metrics, wrapping, ANSI parsing, canvas and borders ([6e164b9](https://github.com/telip007/stipple/commit/6e164b94b54715c37820e2f60417f3be9eaec77e))
* **runtime:** write screen reader frames in the frame writer's screen reader mode ([23331bd](https://github.com/telip007/stipple/commit/23331bd5b96e41fff9e6fa7bcd431e6275492d99))
* **terminal:** add raw mode, terminal events, suspend and crash-safe restore ([c313966](https://github.com/telip007/stipple/commit/c313966c8bb4081345d14f4bd5e0d05c2775ec95))
* use the new components in the examples, fix focus updates and re-record demos ([5d46fe6](https://github.com/telip007/stipple/commit/5d46fe667ff2be66d9b0e3b2f5f58b44af44461e))


### Bug Fixes

* close Ink parity gaps in text wrapping, stacks and renderToString ([6fa1c33](https://github.com/telip007/stipple/commit/6fa1c33d8aefe672fdabdbd262d4cfe4077dae35))
* **focus:** don't auto-focus disabled views ([ec94a06](https://github.com/telip007/stipple/commit/ec94a0648789789eac3bc95f2fbc1f1fcbd0a63c))


### Documentation

* add demo recordings to the README ([18091e6](https://github.com/telip007/stipple/commit/18091e6a0054f972e930783441b75ca5b258f89a))
* add open-source setup, CI and wiki pages for releasing and testing ([aa17d2a](https://github.com/telip007/stipple/commit/aa17d2ae7582cd94c08fc3177464a7169aaad137))

## Changelog

Generated by [release-please](https://github.com/googleapis/release-please)
from [Conventional Commits](https://www.conventionalcommits.org/). The project
follows [Semantic Versioning](https://semver.org/); while on `0.x`, breaking
changes bump the minor version.
