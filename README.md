# claudish-tldr

Fork of [gvzdv/claudish-to-english](https://github.com/gvzdv/claudish-to-english) (v0.1.1, MIT) that shows a **short, simple-language summary** of each Claude Code assistant message, produced by a local LLM via [ollama](https://ollama.com). Default language is English; switch it on the fly with `/claudish language <name>`.

Display-only: Claude's reasoning and the transcript keep the original text. On any failure (ollama down, timeout, missing model) it fails open and shows the original message unchanged.

> Renamed from `claudish-to-italian` in 0.3.0, when the target language became runtime-configurable (and the default switched from Italian to English). If you installed the old name, reinstall: `claude plugin uninstall claudish-to-italian@makhbeth-plugins && claude plugin marketplace update makhbeth-plugins && claude plugin install claudish-tldr@makhbeth-plugins`.

## Requirements

- [ollama](https://ollama.com) running locally (`ollama serve`) with the default model pulled: `ollama pull gemma4:26b-mlx` (MLX build, meant for Apple Silicon)
- `jq` and `curl` on `PATH`

## Install

```sh
claude plugin marketplace add MakhBeth/claudish-tldr
claude plugin install claudish-tldr@makhbeth-plugins
```

To use a different/smaller model:

```sh
export CLAUDISH_MODEL=gemma4:12b   # or any ollama model you pulled
```

If you also use the original claudish-to-english plugin, disable it to avoid a double rewrite:

```sh
claude plugin disable claudish-to-english@gvzdv-plugins
```

### Install from a local clone (development)

```sh
git clone https://github.com/MakhBeth/claudish-tldr
claude plugin marketplace add ./claudish-tldr
claude plugin install claudish-tldr@makhbeth-plugins
```

## Config

Same env vars as the original (`CLAUDISH_MODEL`, `CLAUDISH_MODE`, `CLAUDISH_LANG`, `CLAUDISH_MIN_CHARS`, `CLAUDISH_OFF_FILE`, `CLAUDISH_MD_DIR`, ...) — see the headers of `rewrite.sh` and `rewrite-md.sh`. Default model: `gemma4:26b-mlx`. Default language: English.

## Switching on the fly

The `/claudish` slash command switches state mid-session (the hooks re-read the flag files on every message, so no restart is needed):

```
/claudish            # cycle: off -> append -> replace -> off
/claudish off        # pause, show originals only
/claudish on         # resume with the last mode
/claudish append     # original + summary appended (default)
/claudish replace    # summary only
/claudish status     # show the current state
/claudish language italian   # summarise into another language
/claudish language default   # back to English
/claudish last       # reprint the ORIGINAL text of the last assistant message
```

The rewrite is display-only, so the original is never lost: press `ctrl+o` in Claude Code to view the whole original chat (the transcript keeps Claude's untouched text), or use `/claudish last` to reprint just the last message — handy in `replace` mode.

Under the hood it writes `~/.claude/claudish-mode` (`append`/`replace`, overrides `CLAUDISH_MODE`), `~/.claude/claudish-lang` (a language name, overrides `CLAUDISH_LANG`, default English) and creates/removes `~/.claude/claudish-off`. You can drive the same files from a script or hotkey: `touch ~/.claude/claudish-off` to pause, remove it to resume, `echo replace > ~/.claude/claudish-mode` to switch mode.
