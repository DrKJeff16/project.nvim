CMD = nvim --clean --headless

TAGS_CMD = $(CMD) -c 'helptags doc/' -c 'qa!'

.SUFFIXES:

.PHONY: \
	all \
	check \
	clean \
	distclean \
	helptags \
	lint \
	test

all:
	@$(MAKE) helptags
	@$(MAKE) test

test:
	@./scripts/deps.sh mini
	@nvim --headless --clean --noplugin -u ./scripts/minimal_init.lua \
		-c "lua require('mini.test').setup()" \
		-c "lua MiniTest.run({ execute = { reporter = MiniTest.gen_reporter.stdout({ group_depth = 2 }) } })"

helptags:
	@echo -e "\nGenerating helptags...\n"
	@$(TAGS_CMD) > /dev/null 2>&1
	@echo

lint:
	@echo -e "\nRunning StyLua...\n"
	@stylua .
	@echo

check:
	@echo -e "\nRunning selene...\n"
	@selene lua
	@echo

clean:
	@rm -rf doc/tags

distclean: clean
	@rm -rf deps .ropeproject .mypy_cache
# vim: set ts=4 sts=4 sw=0 noet ai si sta:
