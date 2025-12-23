#!/bin/bash

# set -x

# Print args to `/dev/stderr`.
error() {
	local TXT=("$@")
	printf "%s\n" "${TXT[@]}" >&2
	return 0
}

# Kill the execution. By default it exits with code `0`.
# Usage: `die [[N] [[text] [...]]]`
die() {
	local EC=0
	if [[ $# -ge 1 ]] && [[ $1 =~ ^(0|-?[1-9][0-9]*)$ ]]; then
		EC="$1"
		shift
	fi

	if [[ $# -ge 1 ]]; then
		local TXT=("$@")
		if [[ $EC -eq 0 ]]; then
			printf "%s\n" "${TXT[@]}"
		else
			error "${TXT[@]}"
		fi
	fi

	set +x # Make sure to disable debugging
	exit "$EC"
}

__get_mini() {
	if ! [ -d deps/mini.nvim ]; then
		printf "git clone --depth 1 https://github.com/nvim-mini/mini.nvim deps/mini.nvim\n"
		git clone --depth 1 https://github.com/nvim-mini/mini.nvim deps/mini.nvim || return 1
	fi
	return 0
}

if ! [[ -d ./.git ]] && ! [[ -d ./doc ]] && ! [[ -d ./lua ]] && ! [[ -f ./version.txt ]] ; then
	die 1 "Not on the repository root!"
fi

if [[ $# -eq 0 ]]; then
	__get_mini || die 1 "Mini installation failed!"
	die 0
fi

DEP="$1"

case "$DEP" in
	[Mm][Ii][Nn][Ii])
		__get_mini
		die $?
		;;
	*) die 1 "Bad argument \`${DEP}\`" ;;
esac

# vim: set ts=4 sts=4 sw=0 noet ai si sta:
