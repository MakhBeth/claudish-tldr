# claudish-to-italian

Fork of [gvzdv/claudish-to-english](https://github.com/gvzdv/claudish-to-english) (v0.1.1, MIT) that rewrites each Claude Code assistant message into simple **Italian** instead of plain English, using a local LLM via [ollama](https://ollama.com).

Display-only: Claude's reasoning and the transcript keep the original text. On any failure (ollama down, timeout, missing model) it fails open and shows the original message unchanged.

## Requirements

- [ollama](https://ollama.com) running locally (`ollama serve`) with the default model pulled: `ollama pull gemma4:26b-mlx` (MLX build, meant for Apple Silicon)
- `jq` and `curl` on `PATH`

## Install

```sh
claude plugin marketplace add MakhBeth/claudish-to-italian
claude plugin install claudish-to-italian@makhbeth-plugins
```

To use a different/smaller model:

```sh
export CLAUDISH_MODEL=gemma4:12b   # or any ollama model you pulled
```

If you also use the original English plugin, disable it to avoid a double rewrite:

```sh
claude plugin disable claudish-to-english@gvzdv-plugins
```

### Install from a local clone (development)

```sh
git clone https://github.com/MakhBeth/claudish-to-italian
claude plugin marketplace add ./claudish-to-italian
claude plugin install claudish-to-italian@makhbeth-plugins
```

## Config

Same env vars as the original (`CLAUDISH_MODEL`, `CLAUDISH_MODE`, `CLAUDISH_MIN_CHARS`, `CLAUDISH_OFF_FILE`, `CLAUDISH_MD_DIR`, ...) — see the headers of `rewrite.sh` and `rewrite-md.sh`. Default model: `gemma4:26b-mlx`.

## Switching on the fly

The `/claudish` slash command switches state mid-session (the hooks re-read two flag files on every message, so no restart is needed):

```
/claudish            # cycle: off -> append -> replace -> off
/claudish off        # pause, show originals only
/claudish on         # resume with the last mode
/claudish append     # original + Italian summary (default)
/claudish replace    # Italian summary only
/claudish status     # show the current state
/claudish language french    # rewrite into another language
/claudish language default   # back to Italian
/claudish last       # reprint the ORIGINAL text of the last assistant message
```

The rewrite is display-only, so the original is never lost: press `ctrl+o` in Claude Code to view the whole original chat (the transcript keeps Claude's untouched text), or use `/claudish last` to reprint just the last message — handy in `replace` mode.

Under the hood it writes `~/.claude/claudish-mode` (`append`/`replace`, overrides `CLAUDISH_MODE`), `~/.claude/claudish-lang` (a language name, overrides `CLAUDISH_LANG`, default Italian) and creates/removes `~/.claude/claudish-off`. You can drive the same files from a script or hotkey: `touch ~/.claude/claudish-off` to pause, remove it to resume, `echo replace > ~/.claude/claudish-mode` to switch mode.
