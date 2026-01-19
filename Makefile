LUAROCKS_CMD = luarocks install --local
CMD = nvim --clean --headless

TAGS_CMD = $(CMD) -c 'helptags doc/' -c 'qa!'

.PHONY: all check clean distclean helptags install-deps lint test

all: helptags test

install-deps:
	@$(LUAROCKS_CMD) luassert
	@$(LUAROCKS_CMD) busted
	@$(LUAROCKS_CMD) nlua

test:
	@busted spec

helptags:
	@echo -e "Generating helptags...\n"
	@$(TAGS_CMD) > /dev/null 2>&1
	@echo

lint:
	@echo -e "Running StyLua...\n"
	@stylua .
	@echo

check:
	@echo -e "Running selene..."
	@selene lua
	@echo

clean:
	@rm -rf doc/tags

distclean: clean
	@rm -rf deps .ropeproject .mypy_cache
# vim: set ts=4 sts=4 sw=0 noet ai si sta:
