#!/usr/bin/env bash
# A commit, and the version it calls for. Reads the change, suggests a level,
# asks, then raises the .toc's version (tools/release.sh) and commits it with
# the change. Nothing is pushed: a push to main is what releases (release.yml).
#
#   bug fix                                  patch   0.1.0 -> 0.1.1
#   a new feature                            minor   0.1.0 -> 0.2.0
#   every minor feature since the last
#   major has matured                        major   0.4.2 -> 1.0.0
#   nothing under the addon changed
#   (tools, docs, CI): nothing ships         none
#
# Levels count from the last RELEASE, so unreleased bumps stack instead of
# adding up: a fix on top of an unreleased feature stays at 0.2.0, a feature on
# top of an unreleased fix lifts 0.1.1 to 0.2.0. Before the first release the
# .toc stays as it is: everything goes into that release.
#
#   tools/commit.sh [-a] [-m message | -F file] [-l level] [-y] [-n]
#
#   -a, --all           commit everything in the working tree (git add -A);
#                       otherwise what is staged
#   -m, --message MSG   the commit message; -F, --file FILE: read it from FILE
#                       (neither: git opens the editor)
#   -l, --level LEVEL   patch, minor, major or none: skip the questions
#   -y, --yes           do not ask before committing
#   -n, --dry-run       show the evidence, the suggestion and the version only
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
ADDON=WoW/Interface/AddOns/Medalluin
TOC="$ADDON/Medalluin.toc"
REL="$ROOT/tools/release.sh"

die() { echo "commit.sh: $*" >&2; exit 1; }
usage() { sed -n '2,27p' "$0" | sed 's/^# \{0,1\}//'; }

all=false dry=false yes=false level="" msg="" msgfile=""
while (($#)); do
    case $1 in
        -a | --all) all=true ;;
        -n | --dry-run) dry=true ;;
        -y | --yes) yes=true ;;
        -l | --level) level=${2:?--level what?}; shift ;;
        -m | --message) msg=${2:?--message what?}; shift ;;
        -F | --file) msgfile=${2:?--file what?}; shift ;;
        -h | --help) usage; exit 0 ;;
        *) usage >&2; exit 1 ;;
    esac
    shift
done
case $level in "" | patch | minor | major | none) ;; *) die "level '$level': patch, minor, major or none" ;; esac
cd "$ROOT"

# ------------------------------------------------------------ the change
# name-status lines; with --all, the working tree against HEAD and the
# untracked files as added
changes() {
    if $all; then
        git diff HEAD --name-status
        git ls-files --others --exclude-standard | sed 's/^/A\t/'
    else
        git diff --cached --name-status
    fi
}
# the patch itself, untracked files included as all-new
patch() {
    if $all; then
        git diff HEAD
        git ls-files --others --exclude-standard -z | while IFS= read -r -d '' f; do
            git diff --no-index -- /dev/null "$f" || true
        done
    else
        git diff --cached
    fi
}

CHANGES=$(changes)
[[ -n $CHANGES ]] || die "nothing to commit$($all || echo ' (nothing staged; -a takes the working tree)')"
PATCH=$(patch)

# ------------------------------------------------------------ the evidence
# what ships: anything under the addon's folder
shipped=$(awk -F'\t' -v a="$ADDON/" 'index($NF, a) == 1 { n++ } END { print n + 0 }' <<<"$CHANGES")
# new code files in the addon
newCode=$(awk -F'\t' -v a="$ADDON/" '$1 == "A" && index($NF, a) == 1 && $NF ~ /\.(lua|xml)$/ { print $NF }' <<<"$CHANGES")
# options gained, net of options removed (a control moved is not new)
controls() {
    awk -v sign="$1" -v a="$ADDON/options/" '
        /^\+\+\+ / { f = substr($0, 7); next }
        /^--- / { next }
        index(f, a) == 1 && substr($0, 1, 1) == sign &&
            /(Check|Choice|Color|Button)\("|kind = "(check|choice|color|slider|button|key)"/ { n++ }
        END { print n + 0 }' <<<"$PATCH"
}
netControls=$(($(controls +) - $(controls -)))
# key bindings gained, in the addon's own files (not this script's pattern)
bindings=$(awk -v a="$ADDON/" '
    /^\+\+\+ / { f = substr($0, 7); next }
    index(f, a) == 1 && /^\+.*<Binding / { n++ }
    END { print n + 0 }' <<<"$PATCH")
# the message's words
subject=""
if [[ -n $msg ]]; then subject=${msg%%$'\n'*}; elif [[ -n $msgfile ]]; then subject=$(head -n 1 "$msgfile"); fi
fixWords=false
grep -qiE '(^|[^a-z])(fix(es|ed)?|bug|broken|crash(es)?|regression|wrong|error)([^a-z]|$)' <<<"$subject" && fixWords=true

feature=false
[[ -n $newCode || $netControls -gt 0 || $bindings -gt 0 ]] && feature=true
if ((shipped == 0)); then suggest=none
elif $feature; then suggest=minor
else suggest=patch
fi

echo "The change"
echo "  files: $(wc -l <<<"$CHANGES"), $shipped of them in the addon"
[[ -n $newCode ]] && echo "  new code: $(tr '\n' ' ' <<<"$newCode")"
echo "  options: net $netControls added; key bindings: $bindings added"
[[ -n $subject ]] && echo "  message: \"$subject\"$($fixWords && echo ' (reads as a fix)')"
echo "  suggests: $suggest"

# ------------------------------------------------------------ the questions
# a terminal to ask on (one that opens, not only one that exists)
have_tty() { { : </dev/tty; } 2>/dev/null; }
ask() {   # ask "question" default(y|n) -> 0 for yes
    local answer hint=" [y/N] "
    [[ $2 == y ]] && hint=" [Y/n] "
    read -r -p "$1$hint" answer </dev/tty || answer=""
    answer=${answer:-$2}
    [[ $answer =~ ^[Yy] ]]
}
interactive=false
[[ -z $level ]] && ! $dry && interactive=true
if $interactive; then
    have_tty || die "no terminal to ask on: pass --level (patch, minor, major or none)"
    echo
    if ((shipped == 0)); then
        if ask "Nothing in the addon changed, so nothing ships. Leave the version be?" y; then level=none
        else level=patch
        fi
    elif ask "Does this add something a player can use that was not there before (an option, a page, a frame, a key binding, a command)?" "$($feature && echo y || echo n)"; then
        level=minor
    elif ask "Does it fix something that was broken?" "$($fixWords && echo y || echo n)"; then
        level=patch
    else
        echo "  It still ships (art, wording, a cleanup): a patch."
        level=patch
    fi
fi
[[ -n $level ]] || level=$suggest

# the major: asked only once a minor has shipped since the last major
last=$("$REL" last)
if [[ $level == patch || $level == minor ]] && [[ -n $last ]]; then
    major=${last%%.*}
    # the tags, and the minor pushed to main if its tag is not here yet
    sticky=$("$REL" last sticky)
    minors=$( { git tag --list "v$major.*.0"; [[ $sticky == "$major".* ]] && echo "v$sticky"; } \
        | grep -vE "^v$major\.0\.0$" | sort -uV | tr '\n' ' ' || true)
    since="since v$major.0.0"
    git rev-parse -q --verify "refs/tags/v$major.0.0" >/dev/null || since="in $major.x"
    if [[ -n $minors ]]; then
        if $interactive; then
            echo
            echo "Minors shipped $since: $minors"
            if ask "Have they all matured (settled, no known bugs, nothing half-built), so this is $((major + 1)).0.0?" n; then
                level=major
            fi
        else
            echo "  minors shipped $since: $minors(all matured? then --level major)"
        fi
    fi
fi
[[ $level != "$suggest" ]] && echo "  level: $level (the evidence suggested $suggest)"

# ------------------------------------------------------------ the version
current=$(sed -n 's/^## Version:[[:space:]]*\([^[:space:]]*\).*/\1/p' "$TOC" | head -n 1)
if [[ $level == none ]]; then
    to=$current
    echo "version: $current (nothing ships)"
else
    to=$("$REL" target "$level")
    if [[ -z $last ]]; then
        echo "version: $current: not released yet, so the $level goes into v$current"
    elif [[ $to == "$current" ]]; then
        echo "version: $current: already the $level after v$last, unreleased"
    else
        echo "version: $current -> $to ($level after v$last)"
    fi
fi

$dry && exit 0
if ! $yes && have_tty && ! ask "Commit?" y; then die "nothing done"; fi

# ------------------------------------------------------------ the commit
$all && git add -A
if [[ $to != "$current" ]]; then
    "$REL" set "$to" >/dev/null
    git add "$TOC"
fi
if [[ -n $msg ]]; then git commit -q -m "$msg"
elif [[ -n $msgfile ]]; then git commit -q -F "$msgfile"
else git commit -q
fi
git log --oneline -1
