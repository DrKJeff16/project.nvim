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

LUALS_URL="https://github.com/LuaLS/lua-language-server/releases/download/3.7.4/lua-language-server-3.7.4-darwin-x64.tar.gz"

__get_mini() {
	if ! [ -d deps/mini.nvim ]; then
		printf "git clone --depth 1 https://github.com/nvim-mini/mini.nvim deps/mini.nvim\n"
		git clone --depth 1 https://github.com/nvim-mini/mini.nvim deps/mini.nvim || return 1
	fi
	return 0
}

__get_lua_ls() {
	if [[ -d .ci/lua-ls ]]; then
		printf "rm -rf .ci/lua-ls/log\n"
		rm -rf .ci/lua-ls/log
		return 0
	fi

	printf "%s\n" "mkdir -p .ci/lua-ls" "curl -sL \"\$LUALS_URL\" | tar xzf - -C \"\$(pwd)/.ci/lua-ls\""

	mkdir -p .ci/lua-ls
	curl -sL "$LUALS_URL" | tar xzf - -C "$(pwd)/.ci/lua-ls"

	return $?
}

if [[ $# -eq 0 ]]; then
	__get_mini || die 1 "Mini installation failed!"
	__get_lua_ls || die 1 "LuaLS installation failed!"
	die 0
fi

DEP="$1"

case "$DEP" in
[Mm][Ii][Nn][Ii])
	__get_mini
	die $?
	;;
[Ll][Uu][Aa][Ll][Ss])
	__get_lua_ls
	die $?
	;;
*) die 1 "Bad argument \`${DEP}\`" ;;
esac
