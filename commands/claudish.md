---
description: Switch the rewrite on the fly — on, off, append, replace, "language <name>", or "last" to reprint the original of the last message (no argument cycles off → append → replace)
argument-hint: "[on|off|append|replace|language <name>|last|status]"
allowed-tools: Bash("${CLAUDE_PLUGIN_ROOT}"/claudish-ctl.sh:*)
---

Claudish state after applying "$ARGUMENTS": !`"${CLAUDE_PLUGIN_ROOT}/claudish-ctl.sh" $ARGUMENTS`

If the argument was "last", the script output above is the ORIGINAL text of the last assistant message: reply with the literal line `<!-- claudish:original -->` as the VERY FIRST line (it tells the display hook not to summarise this reply and is stripped from view), then one short intro line (remind the user that ctrl+o shows the whole original chat), then the text verbatim. Otherwise tell the user the resulting claudish state in one short line (off = originals only; append = original + summary; replace = summary only; the language in parentheses is the rewrite language). If the script errored, show its message instead. Do nothing else.
