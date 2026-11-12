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
   - **none**: nothing under `WoW/Interface/AddOns/Medalluin` or any companion
     addon (`WoW/Interface/AddOns/mdlui_*`) changed (tools, the harness, art
     sources, docs, CI). Nothing ships.
   - **minor**: it adds something a player can use that was not there before:
     an option, a page, a frame, a key binding, a slash command, or a companion
     addon. An option moved or renamed is not new.
   - **patch**: it fixes something that was broken, or ships anything else (art,
     wording, a cleanup).
   - **major**: never chosen per commit. A major follows a plan (`plan.md`) the
     user writes when they decide everything is ready; do not ask about it, and
     pass `--level major` only when the user says to.
3. Commit: `tools/commit.sh -a -l <level> -F <file>` with the message in a file
   in the scratchpad (end it with the attribution trailer), or `-m` for one
   line.
4. Report the version line it printed. If the evidence suggested a different
   level from the one you chose, say why.

Levels count from the last release, so bumps between pushes stack instead of
adding up: several fixes after a feature stay at that feature's minor.

Release tags: `commit.sh` first runs `tools/release.sh tags`, which tags here
the releases GitHub tagged, rebuilt from this clone's record of its own pushes
(no fetch). Tags mirror releases only: never tag an unpushed commit, and never
move a tag (a fetch would then reject GitHub's as a clobber).
