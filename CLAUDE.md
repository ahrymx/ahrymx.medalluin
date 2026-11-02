# Medalluin

## Committing

Commit only when asked, and never push, tag or touch the remote: the user does
every GitHub action. A push to `main` with a new `.toc` version is what
releases (`.github/workflows/release.yml`).

Every commit goes through `tools/commit.sh`, which raises the `.toc`'s version
for the change and commits the two together. It cannot ask you questions (no
terminal), so answer them yourself:

1. See the evidence first, without writing anything:
   `tools/commit.sh -a -n -m "<subject>"` (drop `-a` to commit only what is
   staged).
2. Pick the level from what the change *is*; the evidence is a hint, not the
   answer:
   - **none**: nothing under `WoW/Interface/AddOns/Medalluin` changed (tools,
     the harness, art sources, docs, CI). Nothing ships.
   - **minor**: it adds something a player can use that was not there before:
     an option, a page, a frame, a key binding, a slash command. An option moved
     or renamed is not new.
   - **patch**: it fixes something that was broken, or ships anything else (art,
     wording, a cleanup).
   - **major**: when every minor feature since the last major has matured. That is
     the user's call, never yours. When the script lists "minors shipped", say so
     in your report and ask; do not pass `--level major` unless the user has said
     to.
3. Commit: `tools/commit.sh -a -l <level> -F <file>` with the message in a file
   in the scratchpad (end it with the attribution trailer), or `-m` for one
   line.
4. Report the version line it printed. If the evidence suggested a different
   level from the one you chose, say why.

Levels count from the last release, so bumps between pushes stack instead of
adding up: several fixes after a feature stay at that feature's minor.
