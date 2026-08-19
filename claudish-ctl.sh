#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# claudish-ctl.sh — runtime state switcher backing the /claudish command.
#
# Env vars are frozen at session launch, so nothing can flip CLAUDISH_* mid-
# session. Files can: the hooks re-read these on every message. This script
# only writes/removes them — the hooks do the rest.
#   off-file      (default ~/.claude/claudish-off)      exists -> rewrites
#                 paused (the pre-existing kill switch, unchanged)
#   runtime file  (default ~/.claude/claudish-runtime)  key=value lines that
#                 override the matching env vars while present:
#                   mode=append|replace   display mode      (rewrite.sh)
#                   style=tldr|5y         rewrite style     (rewrite.sh)
#                   language=<name>       output language   (lang.sh, cleaned)
#                   model=<name>          model, both hooks (providers.sh)
#
# Usage: claudish-ctl.sh [on|off|append|replace|style [name]|language [name]|model [name]|last|status|cycle]
#   on            resume rewrites (keeps the current mode)
#   off           pause rewrites (originals only; also pauses the Markdown hook)
#   append        original + rewrite appended (and turn on)
#   replace       rewrite only (and turn on)
#   style X       rewrite style: "tldr" (short summary) or "5y" (explain like
#                 I'm five); no name / "default" resets to the plain rewrite.
#                 A custom CLAUDISH_PROMPT_FILE always wins over styles
#   language X    rewrite into language X, e.g. "language french"
#                 (no name / "default" resets to the env/settings; turns on)
#   model X       use model X, e.g. "model gemma4:12b" (no name / "default"
#                 resets to the env/provider default; turns on)
#   last          print the ORIGINAL text of the last assistant message, taken
#                 from the most recent session transcript (useful in replace
#                 mode; ctrl+o shows the whole original chat)
#   status        print the current state
#   cycle         off -> append -> replace -> off (default with no argument)
#
# Prints the resulting state as "claudish: <off|append|replace> (...)".
# ---------------------------------------------------------------------------
set -uo pipefail

OFF_FILE="${CLAUDISH_OFF_FILE:-$HOME/.claude/claudish-off}"
RUNTIME_FILE="${CLAUDISH_RUNTIME_FILE:-$HOME/.claude/claudish-runtime}"

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"

# The slash command passes everything the user typed as ONE quoted string, so
# nothing in it is ever shell syntax. Split it into arguments here (plain
# word splitting, globbing off — never eval).
if [ $# -le 1 ]; then
  set -f
  # shellcheck disable=SC2086
  set -- ${1:-}
  set +f
fi

fail() { printf 'claudish-ctl: %s\n' "$1" >&2; exit 1; }

get_key() { sed -n "s/^$1=//p" "$RUNTIME_FILE" 2>/dev/null | head -n1; }

# set_key KEY VALUE — replace/append one key=value line, preserving the other
# keys; an empty VALUE removes the key. The file is removed once empty, so
# "everything default" is the same absent-file state as a fresh install.
set_key() {
  _rest="$(grep -v "^$1=" "$RUNTIME_FILE" 2>/dev/null | grep -v '^$')" || _rest=""
  {
    { [ -z "$_rest" ] || printf '%s\n' "$_rest"; } &&
    { [ -z "$2" ]     || printf '%s=%s\n' "$1" "$2"; }
  } 2>/dev/null > "$RUNTIME_FILE" || fail "cannot write $RUNTIME_FILE"
  [ -s "$RUNTIME_FILE" ] || rm -f "$RUNTIME_FILE"
}

current_mode() {
  case "$(get_key mode | tr -d '[:space:]')" in
    append)  printf 'append' ;;
    replace) printf 'replace' ;;
    *)       printf '%s' "${CLAUDISH_MODE:-append}" ;;
  esac
}

current_style() {
  case "$(get_key style | tr -d '[:space:]')" in
    tldr) printf 'tldr' ;;
    5y)   printf '5y' ;;
    *)    case "${CLAUDISH_STYLE:-}" in tldr|5y) printf '%s' "$CLAUDISH_STYLE" ;; *) printf 'default' ;; esac ;;
  esac
}

state() { [ -f "$OFF_FILE" ] && printf 'off' || current_mode; }

turn_on() { rm -f "$OFF_FILE" 2>/dev/null || fail "cannot remove $OFF_FILE"; }

set_mode() { set_key mode "$1"; turn_on; }

cmd="${1:-cycle}"
case "$cmd" in
  last)
    # The rewrite is display-only: transcripts always keep Claude's original
    # text. Transcripts live under ~/.claude/projects/<encoded cwd>/, so scope
    # the search to the CURRENT project's directory (the command runs in the
    # session's cwd) and take the most recently touched transcript there —
    # with several sessions open on the SAME project that is still the best
    # available guess. Fall back to all projects when the encoded directory
    # does not exist (e.g. the session moved into a subdirectory).
    proj="$(printf '%s' "$PWD" | sed 's/[^A-Za-z0-9]/-/g')"
    tp="$(ls -t "$HOME/.claude/projects/$proj"/*.jsonl 2>/dev/null | head -n1)"
    [ -n "$tp" ] || tp="$(ls -t "$HOME/.claude/projects"/*/*.jsonl 2>/dev/null | head -n1)"
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
  on)      turn_on ;;
  off)     : > "$OFF_FILE" 2>/dev/null || fail "cannot create $OFF_FILE" ;;
  append)  set_mode append ;;
  replace) set_mode replace ;;
  style)
    s="$(printf '%s' "${2:-}" | tr -d '[:space:]')"
    case "$s" in
      ''|default|Default) set_key style "" ;;
      tldr|5y)            set_key style "$s" ;;
      *) printf 'claudish-ctl: unknown style "%s" (use tldr|5y|default)\n' "$s" >&2; exit 2 ;;
    esac
    turn_on
    ;;
  language)
    # Stored raw (capped, keys stop at the first newline); lang.sh cleans it
    # on every read exactly like the env and settings sources — a language
    # name survives, free text does not.
    shift
    lang="$(printf '%.200s' "$*" | tr -d '\n')"
    case "$lang" in
      ''|default|Default) set_key language "" ;;
      *)                  set_key language "$lang" ;;
    esac
    turn_on
    ;;
  model)
    # Sanitise to the characters model names use (providers.sh re-checks).
    m="$(printf '%s' "${2:-}" | tr -cd 'A-Za-z0-9:._/-' | head -c 64)"
    case "$m" in
      ''|default|Default) set_key model "" ;;
      *)                  set_key model "$m" ;;
    esac
    turn_on
    ;;
  status)  ;;
  cycle)
    case "$(state)" in
      off)    set_mode append ;;
      append) set_mode replace ;;
      *)      : > "$OFF_FILE" 2>/dev/null || fail "cannot create $OFF_FILE" ;;
    esac
    ;;
  *)
    printf 'claudish-ctl: unknown command "%s" (use on|off|append|replace|style [name]|language [name]|model [name]|last|status|cycle)\n' "$cmd" >&2
    exit 2
    ;;
esac

# Status line: source the hooks' own resolvers, so what is printed is exactly
# what the next rewrite will use (provider default model, runtime file,
# settings fallbacks included). Either file missing degrades to a placeholder.
dbg() { :; }
MODEL=""
. "$SELF_DIR/providers.sh" 2>/dev/null || true
claudish_language() { :; }
. "$SELF_DIR/lang.sh" 2>/dev/null || true
lang="$(claudish_language "$PWD" 2>/dev/null)"
printf 'claudish: %s (style: %s, language: %s, model: %s)\n' \
  "$(state)" "$(current_style)" "${lang:-session default}" "${MODEL:-unknown}"
