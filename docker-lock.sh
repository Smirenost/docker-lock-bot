#!/usr/bin/env bash

set -euo pipefail

update_branch="add-docker-lock"
lockfile="docker-lock.json"

function should_commit() {
    local branch

    branch="${1}"

    # if no diff -> ""
    # if diff -> "string with diff"
    # if file does not exist -> "DOES NOT EXIST"
    git diff "${branch}:${lockfile}" "${lockfile}" 2>/dev/null || echo "DOES NOT EXIST"
}

function git_config() {
    git config --global user.email "michaelsethperel@gmail.com"
    git config --global user.name "Michael Perel"
}

function main() {
    local token
    local owner
    local repo
    local default_branch

    token="${1}"
    owner="${2}"
    repo="${3}"
    default_branch="${4}"

    local tmp_dir
    tmp_dir="$(mktemp -d -t tmp-XXXXXXXXXXXXXXX)"
    trap "rm -rf ${tmp_dir}" EXIT

    cd "${tmp_dir}"
    git clone "https://x-access-token:${token}@github.com/${owner}/${repo}.git"
    cd "${repo}"

    docker lock generate

    local update_branch_exists
    update_branch_exists="$(git branch -a | tr -d " " | grep -e "^remotes/origin/${update_branch}$" || echo "")"

    if [[ "${update_branch_exists}" != "" ]]; then
        # branch exists
        if [[ "$(should_commit remotes/origin/${update_branch})" != "" ]]; then
            # should commit
            git_config
            mv "${lockfile}" ../
            git checkout ${update_branch} >&2
            mv "../${lockfile}" .
            git add "${lockfile}"
            git commit -m "Updated Lockfile" >&2
            git push >&2
            printf "true"
        fi
    else
        # branch does not exit
        if [[ "$(should_commit "${default_branch}")" != "" ]]; then
            # should commit
            git_config
            git checkout -b "${update_branch}" >&2
            git add "${lockfile}"
            git commit -m "Updated Lockfile" >&2
            git push --set-upstream origin "${update_branch}" >&2
            printf "true"
        fi
    fi
}

main "${@}"
