CMD = nvim --clean --headless

TAGS_CMD = $(CMD) -c 'helptags doc/' -c 'qa!'

all:
	@$(MAKE) ensure_eof
	@$(MAKE) helptags
	@$(MAKE) test

ensure_eof: scripts/ensure_eof_comment.py
	@python scripts/ensure_eof_comment.py

test:
	@./scripts/deps.sh mini
	@nvim --headless --clean --noplugin -u ./scripts/minimal_init.lua \
		-c "lua require('mini.test').setup()" \
		-c "lua MiniTest.run({ execute = { reporter = MiniTest.gen_reporter.stdout({ group_depth = 2 }) } })"

helptags:
	@echo -e "\nGenerating helptags...\n"
	@$(TAGS_CMD) > /dev/null 2>&1
	@echo

doc/project-nvim.txt:
	@$(MAKE) helptags

lint:
	@echo -e "\nRunning StyLua...\n"
	@stylua .
	@echo

check:
	@echo -e "\nRunning selene...\n"
	@selene lua
	@echo

clean:
	rm -rf doc/tags

.PHONY: \
	all \
	check \
	clean \
	ensure_eof \
	helptags \
	lint \
	test
