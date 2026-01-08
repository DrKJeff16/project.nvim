LUAROCKS_CMD = luarocks install --local
CMD = nvim --clean --headless

TAGS_CMD = $(CMD) -c 'helptags doc/' -c 'qa!'

.SUFFIXES:

.PHONY: \
	all \
	check \
	clean \
	distclean \
	helptags \
	install-deps \
	lint \
	test

all:
	@$(MAKE) helptags
	@$(MAKE) test

install-deps:
	@$(LUAROCKS_CMD) luassert
	@$(LUAROCKS_CMD) busted
	@$(LUAROCKS_CMD) nlua

test: install-deps
	@busted spec

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
