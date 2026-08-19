# claudish-to-italian

Fork of [gvzdv/claudish-to-english](https://github.com/gvzdv/claudish-to-english) (v0.1.1, MIT) that rewrites each Claude Code assistant message into simple **Italian** instead of plain English, using a local LLM via [ollama](https://ollama.com).

Display-only: Claude's reasoning and the transcript keep the original text. On any failure (ollama down, timeout, missing model) it fails open and shows the original message unchanged.

## Install (local marketplace)

```sh
claude plugin marketplace add /Users/davidedipumpo/Projects/claudish-to-italian
claude plugin install claudish-to-italian@davide-plugins
```

Disable the English original to avoid a double rewrite:

```sh
claude plugin disable claudish-to-english@gvzdv-plugins
```

## Config

Same env vars as the original (`CLAUDISH_MODEL`, `CLAUDISH_MODE`, `CLAUDISH_MIN_CHARS`, `CLAUDISH_OFF_FILE`, `CLAUDISH_MD_DIR`, ...) — see the headers of `rewrite.sh` and `rewrite-md.sh`. Default model: `gemma4:26b-mlx`.

Toggle mid-session: `touch ~/.claude/claudish-off` to pause, remove it to resume.
