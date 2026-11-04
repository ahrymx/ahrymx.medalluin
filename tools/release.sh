#!/usr/bin/env bash
# Medalluin's versions and release packages. The version lives in one place,
# the .toc's "## Version:" line, as MAJOR.MINOR.PATCH; its line tag is vMAJOR.MINOR.
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
#   tools/release.sh last [minor|major]       the newest released version (x.y.z,
#                                             x.y.0, x.0.0): a tag, or the .toc
#                                             pushed to origin/main
#   tools/release.sh tags [--quiet]           tag, here, the releases GitHub tagged
#                                             (vMAJOR.MINOR): read from this clone's
#                                             pushes, no fetch
#   tools/release.sh hook [--remove]          run "tags" after every push to main
#                                             (.git/hooks/reference-transaction)
#   tools/release.sh plan                     what a release of the current .toc
#                                             would be, as KEY=value lines
#                                             (.github/workflows/release.yml reads them)
#   tools/release.sh package <dir>            the addon zipped into <dir>
#   tools/release.sh notes [line]             the commits since the last release;
#                                             line: since the previous minor line's
#                                             tag, so the line's release lists
#                                             everything its x.y.0 and patches did
#
# Two kinds of release (release.yml); only vMAJOR.MINOR and rolling tags exist:
#   rolling   the active line's release, tag "rolling", replaced on every push,
#             marked Latest (the current vMAJOR.MINOR tag moves with it, with
#             no duplicate release of its own)
#   line      one frozen release per earlier minor line (v0.1, v0.2), tag
#             vMAJOR.MINOR, frozen at that line's last patch when X or Y rises
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

# The .toc's version at a git ref, or empty.
toc_at() {
    git -C "$ROOT" show "$1:$ADDON/Medalluin.toc" 2>/dev/null \
        | sed -n 's/^## Version:[[:space:]]*\([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p' | head -n 1 || true
}

# The newest released version from the repository's vMAJOR.MINOR (or legacy
# vMAJOR.MINOR.PATCH) tags, as MAJOR.MINOR.PATCH; empty when none.
# "minor": the newest x.y.0 only; "major": the newest x.0.0.
# "merged": only tags on origin/main's history, so a tag made here and not
# pushed is not taken for a release (the commit side, without CI's checkout).
last_tag() {
    local minor='[0-9]*' scope=() t v
    [[ ${1:-} == major ]] && minor=0
    if [[ ${2:-} == merged ]] && git -C "$ROOT" rev-parse -q --verify refs/remotes/origin/main >/dev/null; then
        scope=(--merged refs/remotes/origin/main)
    fi
    while read -r t; do
        [[ -n $t ]] || continue
        v=$(toc_at "$t")
        [[ -n $v ]] || continue
        if [[ ${1:-} == major ]]; then
            echo "${v%%.*}.0.0"
        elif [[ ${1:-} == minor ]]; then
            echo "${v%.*}.0"
        else
            echo "$v"
        fi
    done < <(git -C "$ROOT" tag --list "${scope[@]}" 'v*' | grep -E "^v[0-9]+\.$minor(\.[0-9]+)?$" || true) \
        | sort -V | tail -n 1
}

# The newest released version as this clone can know it: the newest tag, or
# the .toc's version on origin/main if that is newer. A push to main is a
# release (release.yml tags it there), but its tag stays on GitHub until
# fetched, and the clone's origin/main moves with the push itself. For the
# commit side only (target, last): in CI, origin/main is the commit being
# released, so plan and notes read the tags.
last_released() {
    local tag pushed
    tag=$(last_tag "${1:-}" merged)
    pushed=$(toc_at "refs/remotes/origin/main")
    if [[ -n $pushed ]]; then
        if [[ ${1:-} == major ]]; then
            [[ ${pushed#*.} == 0.0 ]] || pushed=""
        elif [[ ${1:-} == minor ]]; then
            pushed="${pushed%.*}.0"
        fi
    fi
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
    local v line last prev_commit release=true
    v=$(version)
    line=${v%.*}
    last=$(last_tag)
    prev_commit=$(toc_at HEAD~1)
    if [[ ${GITHUB_EVENT_NAME:-} == workflow_dispatch ]]; then
        release=true
    elif [[ -n $last ]] && [[ $v == "$last" ]] && [[ $v == "$prev_commit" ]]; then
        release=false                      # this version is out already and HEAD did not bump it
    elif [[ -n $last ]] && ! newer "$v" "$last" && [[ $v != "$last" ]]; then
        die "the .toc's version $v is not newer than the last release, v$last"
    fi
    echo "version=$v"
    echo "tag=v$line"
    echo "line=$line"
    echo "release=$release"
    echo "previous=${last:+v${last%.*}}"
}

# The addon as players install it: a Medalluin folder (with the LICENSE) in a zip,
# and any optional companion addons as separate <companion>-vX.Y.Z.zip packages.
cmd_package() {
    local out=${1:?package where?} ref=${2:-HEAD} v stage companion cpath
    if [[ $ref == HEAD ]]; then v=$(version); else v=$(toc_at "$ref"); fi
    mkdir -p "$out"
    out=$(cd "$out" && pwd)
    stage=$(mktemp -d)
    trap 'rm -rf "$stage"' RETURN
    # only what git tracks, so nothing local or ignored slips in
    git -C "$ROOT" archive --format=tar "$ref" "$ADDON" | tar -x -C "$stage"
    mv "$stage/$ADDON" "$stage/Medalluin"
    if git -C "$ROOT" cat-file -e "$ref:LICENSE" 2>/dev/null; then
        git -C "$ROOT" show "$ref:LICENSE" > "$stage/Medalluin/LICENSE"
    else
        cp "$ROOT/LICENSE" "$stage/Medalluin/LICENSE"
    fi
    rm -f "$out/Medalluin-v$v.zip"
    (cd "$stage" && zip -qr -X "$out/Medalluin-v$v.zip" Medalluin)
    echo "$out/Medalluin-v$v.zip"
    for companion in $(companions); do
        cpath="WoW/Interface/AddOns/$companion"
        if git -C "$ROOT" cat-file -e "$ref:$cpath/$companion.toc" 2>/dev/null; then
            git -C "$ROOT" archive --format=tar "$ref" "$cpath" | tar -x -C "$stage"
            mv "$stage/$cpath" "$stage/$companion"
            rm -f "$out/${companion}-v$v.zip"
            (cd "$stage" && zip -qr -X "$out/${companion}-v$v.zip" "$companion")
            echo "$out/${companion}-v$v.zip"
        elif [[ $ref == HEAD && -f "$ROOT/$cpath/$companion.toc" ]]; then
            cp -r "$ROOT/$cpath" "$stage/$companion"
            rm -f "$out/${companion}-v$v.zip"
            (cd "$stage" && zip -qr -X "$out/${companion}-v$v.zip" "$companion")
            echo "$out/${companion}-v$v.zip"
        fi
    done
}

cmd_notes() {
    local ref=${1:-HEAD} v line sha subj cur="" prev=""
    [[ $ref == line ]] && ref=${2:-HEAD}
    if [[ $ref == HEAD ]]; then v=$(version); else v=$(toc_at "$ref"); fi
    line=${v%.*}
    [[ $line == 0.1 ]] && { echo "The first release."; echo; }
    while read -r sha subj; do
        [[ -n $sha ]] || continue
        cur=$(toc_at "$sha")
        cur=${cur:-$v}
        [[ ${cur%.*} == "$line" ]] || break
        if [[ $cur != "$prev" ]]; then
            [[ -n $prev ]] && echo
            echo "## v$cur"
            echo
            prev=$cur
        fi
        echo "- $subj"
    done < <(git -C "$ROOT" log --first-parent --no-merges --format='%H %s' "$ref")
}

# The release tags GitHub holds (vMAJOR.MINOR), made here from main's commit
# history (refs/remotes/origin/main locally, or a ref passed by CI): each minor
# line's tag sits at the newest commit of that line. Any old 3-part vX.Y.Z tags
# here are removed so local tags match GitHub's.
cmd_tags() {
    local quiet=false tip="refs/remotes/origin/main" sha v line tag old
    while (($#)); do
        case $1 in
            --quiet) quiet=true ;;
            *) tip=$1 ;;
        esac
        shift
    done
    for old in $(git -C "$ROOT" tag --list 'v*.*.*'); do
        git -C "$ROOT" tag -d "$old" >/dev/null
    done
    git -C "$ROOT" rev-parse -q --verify "$tip" >/dev/null || return 0
    local -A seen=()
    # newest first: the first commit seen for a minor line is where vMAJOR.MINOR sits
    while read -r sha; do
        git -C "$ROOT" cat-file -e "$sha:.github/workflows/release.yml" 2>/dev/null || continue
        v=$(git -C "$ROOT" show "$sha:$ADDON/Medalluin.toc" 2>/dev/null \
            | sed -n 's/^## Version:[[:space:]]*\([0-9]*\.[0-9]*\.[0-9]*\)[[:space:]]*$/\1/p' | head -n 1)
        [[ -n $v ]] || continue
        line=${v%.*}
        [[ -z ${seen[$line]:-} ]] || continue
        seen[$line]=1
        tag=v$line
        git -C "$ROOT" tag -f "$tag" "$sha" >/dev/null
        $quiet || echo "$tag  ${sha:0:7} ($v)"
    done < <(git -C "$ROOT" log --first-parent --format=%H "$tip" 2>/dev/null)
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
    version) shift; if [[ -n ${1:-} ]]; then toc_at "$1"; else version; fi ;;
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
