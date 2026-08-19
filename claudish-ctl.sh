#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# claudish-ctl.sh — runtime state switcher backing the /claudish command.
#
# The hooks re-read two files on every message, so this works mid-session:
#   off-file  (default ~/.claude/claudish-off)   exists -> rewrites paused
#   mode-file (default ~/.claude/claudish-mode)  append|replace -> display mode
#
# Usage: claudish-ctl.sh [on|off|append|replace|language [name]|status|cycle]
#   on            resume rewrites (keeps the current mode)
#   off           pause rewrites (originals only; also pauses the Markdown hook)
#   append        original + summary appended (and turn on)
#   replace       summary only (and turn on)
#   language X    rewrite into language X, e.g. "language french"
#                 (no name / "default" resets to English; also turns on)
#   model X       use ollama model X, e.g. "model gemma4:12b"
#                 (no name / "default" resets to the env/default model)
#   last          print the ORIGINAL text of the last assistant message, taken
#                 from the most recent session transcript (useful in replace
#                 mode; ctrl+o shows the whole original chat)
#   status        print the current state
#   cycle         off -> append -> replace -> off (default with no argument)
#
# Prints the resulting state as "claudish: <off|append|replace> (<language>)".
# ---------------------------------------------------------------------------
set -uo pipefail

OFF_FILE="${CLAUDISH_OFF_FILE:-$HOME/.claude/claudish-off}"
MODE_FILE="${CLAUDISH_MODE_FILE:-$HOME/.claude/claudish-mode}"
LANG_FILE="${CLAUDISH_LANG_FILE:-$HOME/.claude/claudish-lang}"
MODEL_FILE="${CLAUDISH_MODEL_FILE:-$HOME/.claude/claudish-model}"

current_model() {
  m=""
  [ -f "$MODEL_FILE" ] && m="$(head -c 128 "$MODEL_FILE" 2>/dev/null | tr -cd 'A-Za-z0-9:._/-' | head -c 64)"
  [ -n "$m" ] && printf '%s' "$m" || printf '%s' "${CLAUDISH_MODEL:-gemma4:26b-mlx}"
}

current_lang() {
  l=""
  [ -f "$LANG_FILE" ] && l="$(head -c 64 "$LANG_FILE" 2>/dev/null | tr -cd 'A-Za-z -' | head -c 32)"
  [ -n "$l" ] && printf '%s' "$l" || printf '%s' "${CLAUDISH_LANG:-English}"
}

current_mode() {
  m=""
  [ -f "$MODE_FILE" ] && m="$(cat "$MODE_FILE" 2>/dev/null | tr -d '[:space:]')"
  case "$m" in
    append|replace) printf '%s' "$m" ;;
    *) printf '%s' "${CLAUDISH_MODE:-append}" ;;
  esac
}

state() { [ -f "$OFF_FILE" ] && printf 'off' || current_mode; }

set_mode() { printf '%s\n' "$1" > "$MODE_FILE" && rm -f "$OFF_FILE"; }

cmd="${1:-cycle}"
case "$cmd" in
  last)
    # The rewrite is display-only: transcripts always keep Claude's original
    # text. The most recently touched transcript is the live session's.
    tp="$(ls -t "$HOME/.claude/projects"/*/*.jsonl 2>/dev/null | head -n1)"
    [ -n "$tp" ] || { printf 'claudish-ctl: no session transcript found\n' >&2; exit 1; }
    jq -rs '
      [ .[]
        | select(.type=="assistant" and .isSidechain!=true)
        | [.message.content[]? | select(.type=="text") | .text]
        | join("\n\n")
        | select(length>0) ]
      | last // "claudish-ctl: no assistant message in the transcript yet"
    ' "$tp" 2>/dev/null || { printf 'claudish-ctl: could not parse %s\n' "$tp" >&2; exit 1; }
    exit 0
    ;;
  on)      rm -f "$OFF_FILE" ;;
  off)     : > "$OFF_FILE" ;;
  append)  set_mode append ;;
  replace) set_mode replace ;;
  language)
    # Sanitise like the hooks do: the name ends up inside the LLM prompt.
    lang="$(printf '%s' "${2:-}" | tr -cd 'A-Za-z -' | head -c 32)"
    case "$lang" in
      ''|default|Default) rm -f "$LANG_FILE" ;;
      *) printf '%s\n' "$lang" > "$LANG_FILE" ;;
    esac
    rm -f "$OFF_FILE"
    ;;
  model)
    # Sanitise to the characters ollama model names use.
    m="$(printf '%s' "${2:-}" | tr -cd 'A-Za-z0-9:._/-' | head -c 64)"
    case "$m" in
      ''|default|Default) rm -f "$MODEL_FILE" ;;
      *) printf '%s\n' "$m" > "$MODEL_FILE" ;;
    esac
    rm -f "$OFF_FILE"
    ;;
  status)  ;;
  cycle)
    case "$(state)" in
      off)    set_mode append ;;
      append) set_mode replace ;;
      *)      : > "$OFF_FILE" ;;
    esac
    ;;
  *)
    printf 'claudish-ctl: unknown command "%s" (use on|off|append|replace|language [name]|model [name]|last|status|cycle)\n' "$cmd" >&2
    exit 2
    ;;
esac

printf 'claudish: %s (%s, %s)\n' "$(state)" "$(current_lang)" "$(current_model)"
