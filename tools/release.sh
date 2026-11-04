#!/usr/bin/env bash
# Medalluin's versions and release packages. The version lives in one place,
# the .toc's "## Version:" line, as MAJOR.MINOR.PATCH; its tag is vMAJOR.MINOR.PATCH.
#
#   tools/release.sh bump patch|minor|major   raise the .toc's version (a minor
#                                             or major bump zeroes what is below it)
#   tools/release.sh target patch|minor|major the version a change of that level
#                                             needs: one level up from the last
#                                             release, unless the .toc is already
#                                             there (unreleased bumps stack, they do
#                                             not add up); before any release, the
#                                             .toc as it is. Writes nothing.
#   tools/release.sh set X.Y.Z                write the .toc's version
#   tools/release.sh last [minor|major]       the newest released version (x.y.0, x.0.0):
#                                             a tag, or the .toc pushed to origin/main
#   tools/release.sh tags [--quiet]           tag, here, the releases GitHub tagged:
#                                             read from this clone's pushes, no fetch
#   tools/release.sh hook [--remove]          run "tags" after every push to main
#                                             (.git/hooks/reference-transaction)
#   tools/release.sh plan                     what a release of the current .toc
#                                             would be, as KEY=value lines
#                                             (.github/workflows/release.yml reads them)
#   tools/release.sh package <dir>            the addon zipped into <dir>
#   tools/release.sh notes [line]             the commits since the last version tag;
#                                             line: since the previous line's last
#                                             version, so the line's release lists
#                                             everything its x.y.0 and patches did
#
# Two kinds of release (release.yml); every version keeps its tag for good:
#   rolling   every version: one release, tag "rolling", replaced each time,
#             so it is always the newest build and its download link never changes
#   line      one per minor line (0.2, 1.0), on its newest patch's tag: each
#             patch moves it there, and the next minor or major freezes it
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
ADDON=WoW/Interface/AddOns/Medalluin
TOC="$ROOT/$ADDON/Medalluin.toc"

die() { echo "release.sh: $*" >&2; exit 1; }

version() {
    local v
    v=$(sed -n 's/^## Version:[[:space:]]*\([^[:space:]]*\).*/\1/p' "$TOC" | head -n 1)
    [[ $v =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "the .toc's version '$v' is not MAJOR.MINOR.PATCH"
    echo "$v"
}

# The newest version tag in the repository, without its v; empty when none.
# "minor": the newest x.y.0 only; "major": the newest x.0.0.
# "merged": only tags on origin/main's history, so a tag made here and not
# pushed is not taken for a release (the commit side, without CI's checkout).
last_tag() {
    local minor='[0-9]*' patch='[0-9]*' scope=()
    [[ ${1:-} == minor ]] && patch=0
    [[ ${1:-} == major ]] && minor=0 && patch=0
    if [[ ${2:-} == merged ]] && git -C "$ROOT" rev-parse -q --verify refs/remotes/origin/main >/dev/null; then
        scope=(--merged refs/remotes/origin/main)
    fi
    git -C "$ROOT" tag --list "${scope[@]}" 'v*' | sed -n "s/^v\([0-9]*\.$minor\.$patch\)\$/\1/p" | sort -V | tail -n 1
}

# The newest released version as this clone can know it: the newest tag, or
# the .toc's version on origin/main if that is newer. A push to main is a
# release (release.yml tags it there), but its tag stays on GitHub until
# fetched, and the clone's origin/main moves with the push itself. For the
# commit side only (target, last): in CI, origin/main is the commit being
# released, so plan and notes read the tags.
last_released() {
    local tag pushed minor='[0-9]*' patch='[0-9]*'
    [[ ${1:-} == minor ]] && patch=0
    [[ ${1:-} == major ]] && minor=0 && patch=0
    tag=$(last_tag "${1:-}" merged)
    pushed=$(git -C "$ROOT" show "refs/remotes/origin/main:$ADDON/Medalluin.toc" 2>/dev/null \
        | sed -n 's/^## Version:[[:space:]]*\([^[:space:]]*\).*/\1/p' | head -n 1 \
        | sed -n "s/^\([0-9]*\.$minor\.$patch\)\$/\1/p" || true)
    if [[ -n $pushed ]] && { [[ -z $tag ]] || newer "$pushed" "$tag"; }; then echo "$pushed"; else echo "$tag"; fi
}

# a > b, as versions
newer() { [[ $1 != "$2" && $(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n 1) == "$1" ]]; }

# a version one level up
raised() {
    local major minor patch
    IFS=. read -r major minor patch <<<"$1"
    case $2 in
        patch) patch=$((patch + 1)) ;;
        minor) minor=$((minor + 1)); patch=0 ;;
        major) major=$((major + 1)); minor=0; patch=0 ;;
        *) die "which level? patch, minor or major" ;;
    esac
    echo "$major.$minor.$patch"
}

# The optional companion addons (WoW/Interface/AddOns/mdlui_*), each with its
# own <name>.toc.
companions() {
    local dir name
    for dir in "$ROOT/WoW/Interface/AddOns"/mdlui_*; do
        [[ -d "$dir" ]] || continue
        name=$(basename "$dir")
        [[ -f "$dir/$name.toc" ]] && echo "$name"
    done
}

write_version() {
    [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "'$1' is not MAJOR.MINOR.PATCH"
    sed -i "s/^## Version:.*/## Version: $1/" "$TOC"
    local companion ctoc
    for companion in $(companions); do
        ctoc="$ROOT/WoW/Interface/AddOns/$companion/$companion.toc"
        [[ -f "$ctoc" ]] && sed -i "s/^## Version:.*/## Version: $1/" "$ctoc"
    done
}

cmd_bump() {
    local v to
    v=$(version)
    to=$(raised "$v" "${1:-}")
    write_version "$to"
    echo "$v -> $to"
}

cmd_target() {
    local level=${1:-} v last to
    v=$(version)
    last=$(last_released)
    raised 0.0.0 "$level" >/dev/null       # the level is one of the three
    if [[ -z $last ]]; then echo "$v"; return; fi
    to=$(raised "$last" "$level")
    if newer "$to" "$v"; then echo "$to"; else echo "$v"; fi
}

cmd_set() {
    write_version "${1:?set to what?}"
    echo "${1}"
}

cmd_plan() {
    local v last release=true
    v=$(version)
    last=$(last_tag)
    if git -C "$ROOT" rev-parse -q --verify "refs/tags/v$v" >/dev/null; then
        release=false                      # this version is out already
    elif [[ -n $last ]] && ! newer "$v" "$last"; then
        die "the .toc's version $v is not newer than the last release, v$last"
    fi
    echo "version=$v"
    echo "tag=v$v"
    echo "line=${v%.*}"
    echo "release=$release"
    echo "previous=${last:+v$last}"
}

# The addon as players install it: a Medalluin folder (with the LICENSE) in a zip,
# and any optional companion addons as separate <companion>-vX.Y.Z.zip packages.
cmd_package() {
    local out=${1:?package where?} v stage companion cpath
    v=$(version)
    mkdir -p "$out"
    out=$(cd "$out" && pwd)
    stage=$(mktemp -d)
    trap 'rm -rf "$stage"' RETURN
    # only what git tracks, so nothing local or ignored slips in
    git -C "$ROOT" archive --format=tar HEAD "$ADDON" | tar -x -C "$stage"
    mv "$stage/$ADDON" "$stage/Medalluin"
    cp "$ROOT/LICENSE" "$stage/Medalluin/LICENSE"
    rm -f "$out/Medalluin-v$v.zip"
    (cd "$stage" && zip -qr -X "$out/Medalluin-v$v.zip" Medalluin)
    echo "$out/Medalluin-v$v.zip"
    for companion in $(companions); do
        cpath="WoW/Interface/AddOns/$companion"
        if git -C "$ROOT" cat-file -e "HEAD:$cpath/$companion.toc" 2>/dev/null; then
            git -C "$ROOT" archive --format=tar HEAD "$cpath" | tar -x -C "$stage"
            mv "$stage/$cpath" "$stage/$companion"
            rm -f "$out/${companion}-v$v.zip"
            (cd "$stage" && zip -qr -X "$out/${companion}-v$v.zip" "$companion")
            echo "$out/${companion}-v$v.zip"
        elif [[ -f "$ROOT/$cpath/$companion.toc" ]]; then
            cp -r "$ROOT/$cpath" "$stage/$companion"
            rm -f "$out/${companion}-v$v.zip"
            (cd "$stage" && zip -qr -X "$out/${companion}-v$v.zip" "$companion")
            echo "$out/${companion}-v$v.zip"
        fi
    done
}

cmd_notes() {
    local last range v
    if [[ ${1:-} == line ]]; then
        # the newest tag of any earlier line: the release covers the whole line
        v=$(version)
        last=$(git -C "$ROOT" tag --list 'v*' | sed -n 's/^v\([0-9]*\.[0-9]*\.[0-9]*\)$/\1/p' | sort -V \
            | awk -v line="${v%.*}" -F. '$1 "." $2 != line' | while read -r t; do
                newer "$v" "$t" && echo "$t"
            done | tail -n 1)
    else
        last=$(last_tag)
    fi
    if [[ -n $last ]]; then range="v$last..HEAD"; else range=HEAD; fi
    if [[ -z $last ]]; then echo "The first release."; echo; fi
    echo "## Changes"
    echo
    git -C "$ROOT" log --no-merges --format='- %s' $range
}

# The release tags GitHub holds, made here from this clone's own record of
# its pushes (the reflog of origin/main): release.yml tags the first pushed
# head that carries a version with no tag yet, once the workflow is in the
# commit. Lightweight, at the same commits, so a later fetch finds them equal.
# A tag already here is never moved; one at another commit is reported.
cmd_tags() {
    local quiet=false sha v tag at
    [[ ${1:-} == --quiet ]] && quiet=true
    git -C "$ROOT" rev-parse -q --verify refs/remotes/origin/main >/dev/null || return 0
    local -A seen=()
    # oldest first
    while read -r sha; do
        git -C "$ROOT" cat-file -e "$sha:.github/workflows/release.yml" 2>/dev/null || continue
        v=$(git -C "$ROOT" show "$sha:$ADDON/Medalluin.toc" 2>/dev/null \
            | sed -n 's/^## Version:[[:space:]]*\([0-9]*\.[0-9]*\.[0-9]*\)[[:space:]]*$/\1/p' | head -n 1)
        [[ -n $v && -z ${seen[$v]:-} ]] || continue
        seen[$v]=1
        tag=v$v
        if at=$(git -C "$ROOT" rev-parse -q --verify "refs/tags/$tag^{commit}"); then
            [[ $at == "$sha" ]] || echo "release.sh: $tag is at ${at:0:7} here, but was pushed at ${sha:0:7}: left as it is" >&2
            continue
        fi
        git -C "$ROOT" tag "$tag" "$sha"
        $quiet || echo "$tag  ${sha:0:7}"
    done < <(git -C "$ROOT" reflog show --format=%H refs/remotes/origin/main 2>/dev/null | tac)
}

# The hook: git runs it on every ref update; it answers only a push (or fetch)
# that moved origin/main, once the update is committed.
HOOK_MARK="# medalluin: release tags (tools/release.sh hook)"
cmd_hook() {
    local hooks file
    hooks=$(git -C "$ROOT" rev-parse --git-path hooks)
    [[ $hooks == /* ]] || hooks="$ROOT/$hooks"
    file="$hooks/reference-transaction"
    if [[ ${1:-} == --remove ]]; then
        if [[ -f $file ]] && grep -qF "$HOOK_MARK" "$file"; then rm "$file"; echo "removed $file"; fi
        return 0
    fi
    if [[ -f $file ]] && ! grep -qF "$HOOK_MARK" "$file"; then
        die "$file is someone else's hook: add a call to tools/release.sh tags --quiet to it yourself"
    fi
    mkdir -p "$hooks"
    cat >"$file" <<HOOK
#!/bin/sh
$HOOK_MARK
[ "\$1" = committed ] || exit 0
grep -q ' refs/remotes/origin/main\$' || exit 0
"\$(git rev-parse --show-toplevel)/tools/release.sh" tags --quiet || true
HOOK
    chmod +x "$file"
    echo "installed $file"
}

case ${1:-} in
    companions) companions ;;
    tags) shift; cmd_tags "$@" ;;
    hook) shift; cmd_hook "$@" ;;
    bump) shift; cmd_bump "$@" ;;
    target) shift; cmd_target "$@" ;;
    set) shift; cmd_set "$@" ;;
    last) shift; last_released "$@" ;;
    plan) cmd_plan ;;
    package) shift; cmd_package "$@" ;;
    notes) shift; cmd_notes "$@" ;;
    *) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
