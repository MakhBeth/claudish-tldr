# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `/claudish` slash command for runtime switching (`commands/claudish.md` +
  `claudish-ctl.sh`). `on`/`off` drive the existing off-file; every other
  subcommand writes a `key=value` line into ONE runtime file
  (`~/.claude/claudish-runtime`, path: `CLAUDISH_RUNTIME_FILE`) that the hooks
  re-read on every message, so everything switches mid-session without
  restarting: `append`/`replace` (`mode=`), `style tldr|5y|default` (`style=`),
  `language <name>` (`language=`, cleaned by `lang.sh` like every other
  source), `model <name>` (`model=`, sanitised in `providers.sh`, both hooks),
  `status`, and a bare `/claudish` that cycles off → append → replace. Env
  vars keep working as launch-time defaults; a key, while present, wins.
- Rewrite-style presets for the display hook (`CLAUDISH_STYLE` or the runtime
  file's `style=` key): `tldr` produces a clearly shorter summary, `5y`
  explains like you're five; the on-screen label follows (`💬 TL;DR:`,
  `💬 Like you're five:`). Styles replace only the built-in base prompt — the
  output language still applies, and a usable `CLAUDISH_PROMPT_FILE` wins over
  any style. The Markdown hook is unaffected.
- `/claudish last` reprints the ORIGINAL text of the last assistant message
  from the session transcript (the rewrite is display-only, so the transcript
  always has it) — useful in `replace` mode. Such reprints start with a
  `<!-- claudish:original -->` marker line that the display hook strips and
  never rewrites.

## [0.4.0] - 2026-08-14

### Added
- Output language. A rewrite can be pinned to a language with `CLAUDISH_LANG`,
  or with the `language` key in `.claude/settings*.json` — the same key Claude
  Code answers in, read in the same order of precedence (`lang.sh`). The
  on-screen label then names it: `💬 In plain Esperanto:`. An empty
  `CLAUDISH_LANG` ignores the settings key; `English` forces English.

### Changed
- The built-in prompts no longer hard-code English. They ask for plain
  language in the language the input is already written in, so an Esperanto
  session gets an Esperanto rewrite instead of an English one. Set
  `CLAUDISH_LANG=English` to keep the previous behaviour. A prompt supplied
  through `CLAUDISH_PROMPT_FILE` / `CLAUDISH_MD_PROMPT_FILE` is unaffected: it
  still replaces the whole prompt.
- With no language configured, the display label reads `💬 In plain language:`
  rather than `💬 In plain English:`, which it can no longer promise.

## [0.3.0] - 2026-08-13

### Added
- Customizable rewrite prompts. Point the display hook at a prompt file with
  `CLAUDISH_PROMPT_FILE`, or the Markdown hook with `CLAUDISH_MD_PROMPT_FILE`;
  the file's contents replace the built-in prompt wholesale. An unset, empty, or
  unreadable file falls back to the built-in default, so a bad path never stops
  rewrites. Defaults are unchanged.

## [0.2.0] - 2026-08-13

### Added
- Provider layer (`providers.sh`): rewrites can run against local **ollama**
  (default, unchanged), the **Anthropic** Messages API, or any
  **OpenAI-compatible** endpoint, selected with `CLAUDISH_PROVIDER` (#10).
- Runtime kill-switch flag file (`~/.claude/claudish-off`, overridable with
  `CLAUDISH_OFF_FILE`) to pause and resume rewrites mid-session, since env vars
  are frozen at launch (#4).
- Windows setup documentation and model-default guidance (#7).
- Comparison screenshot at the top of the README.

### Fixed
- Markdown `overwrite` mode: the idempotency marker is written after any YAML
  frontmatter, so the frontmatter stays on line 1 where parsers expect it.
  Leftover display-hook temp files are also cleaned up (#1).
- Quote `CLAUDE_PLUGIN_ROOT` in the hook commands so plugin paths containing
  spaces resolve correctly (#6).

## [0.1.1] - 2026-08-10

### Added
- One-time, per-session notice explaining why a rewrite was skipped when the
  provider is unreachable, the call times out, or the model isn't available
  (`CLAUDISH_NOTICE`, default on).

### Changed
- Default model set to `gemma4:26b-mlx` (Apple-silicon MLX build).
- Separate per-hook timeouts: `CLAUDISH_TIMEOUT` (display) and
  `CLAUDISH_MD_TIMEOUT` (Markdown file).
- Added the "Configuring the plugin" section to the README.

## [0.1.0] - 2026-08-10

### Added
- Initial release. A `MessageDisplay` hook (`rewrite.sh`) that rewrites each
  assistant message into plain English with a local ollama model — `append`
  and `replace` display modes, a prose-length gate, and a fail-open contract
  that always leaves Claude's original text on screen if anything goes wrong.
- Optional `PostToolUse` Markdown-file rewrite hook (`rewrite-md.sh`), opt-in by
  directory (`CLAUDISH_MD_DIR`), with `sibling` and `overwrite` modes.

[0.4.0]: https://github.com/gvzdv/claudish-to-english/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/gvzdv/claudish-to-english/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/gvzdv/claudish-to-english/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/gvzdv/claudish-to-english/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/gvzdv/claudish-to-english/releases/tag/v0.1.0
