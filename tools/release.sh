#!/usr/bin/env bash
# Medalluin's versions and release packages. The version lives in one place,
# the .toc's "## Version:" line, as MAJOR.MINOR.PATCH; its tag is vMAJOR.MINOR.PATCH.
#
#   tools/release.sh bump patch|minor|major   raise the .toc's version (a minor
#                                             or major bump zeroes what is below it)
#   tools/release.sh plan                     what a release of the current .toc
#                                             would be, as KEY=value lines
#                                             (.github/workflows/release.yml reads them)
#   tools/release.sh package <dir>            the addon zipped into <dir>
#   tools/release.sh notes [sticky]           the commits since the last version tag;
#                                             sticky: since the last x.y.0, so a minor
#                                             or major lists everything its patches did
#
# Two kinds of release (release.yml):
#   rolling   every version: one release, tag "rolling", replaced each time,
#             so it is always the newest build and its download link never changes
#   sticky    x.y.0 (a minor or major version): a release of its own, kept for good
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
# "sticky": the newest x.y.0 only.
last_tag() {
    local pattern='[0-9]*'
    [[ ${1:-} == sticky ]] && pattern=0
    git -C "$ROOT" tag --list 'v*' | sed -n "s/^v\([0-9]*\.[0-9]*\.$pattern\)\$/\1/p" | sort -V | tail -n 1
}

# a > b, as versions
newer() { [[ $1 != "$2" && $(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n 1) == "$1" ]]; }

cmd_bump() {
    local part=${1:-} v major minor patch
    v=$(version)
    IFS=. read -r major minor patch <<<"$v"
    case $part in
        patch) patch=$((patch + 1)) ;;
        minor) minor=$((minor + 1)); patch=0 ;;
        major) major=$((major + 1)); minor=0; patch=0 ;;
        *) die "bump what? patch, minor or major" ;;
    esac
    local to="$major.$minor.$patch"
    sed -i "s/^## Version:.*/## Version: $to/" "$TOC"
    echo "$v -> $to"
}

cmd_plan() {
    local v last kind release=true
    v=$(version)
    last=$(last_tag)
    if git -C "$ROOT" rev-parse -q --verify "refs/tags/v$v" >/dev/null; then
        release=false                      # this version is out already
    elif [[ -n $last ]] && ! newer "$v" "$last"; then
        die "the .toc's version $v is not newer than the last release, v$last"
    fi
    if [[ ${v##*.} == 0 ]]; then kind=sticky; else kind=rolling; fi
    echo "version=$v"
    echo "tag=v$v"
    echo "kind=$kind"
    echo "release=$release"
    echo "previous=${last:+v$last}"
}

# The addon as players install it: a Medalluin folder (with the LICENSE) in a zip.
cmd_package() {
    local out=${1:?package where?} v stage
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
}

cmd_notes() {
    local last range
    last=$(last_tag "${1:-}")
    if [[ -n $last ]]; then range="v$last..HEAD"; else range=HEAD; fi
    if [[ -z $last ]]; then echo "The first release."; echo; fi
    echo "## Changes"
    echo
    git -C "$ROOT" log --no-merges --format='- %s' $range
}

case ${1:-} in
    bump) shift; cmd_bump "$@" ;;
    plan) cmd_plan ;;
    package) shift; cmd_package "$@" ;;
    notes) shift; cmd_notes "$@" ;;
    *) sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
