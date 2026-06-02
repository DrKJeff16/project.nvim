LUAROCKS_CMD = luarocks install --local
CMD = nvim --clean --headless
TAGS_CMD = $(CMD) -c 'helptags doc/' -c 'qa!'

.PHONY: all check clean distclean helptags install-deps lint test

all: helptags

check: ## Check using selene
	@echo -e "Running selene...\n"
	@selene lua
	@echo

clean: ## Clean the generated helptags
	@rm -rf doc/tags

distclean: clean ## Remove all the unnecessary junk
	@rm -rf deps .ropeproject .mypy_cache

help: ## Prints this help message
	@echo -e "Usage: make [target]\n\nAvailable targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo

helptags: ## Generate Vim helptags
	@echo -e "Generating helptags...\n"
	@$(TAGS_CMD) > /dev/null 2>&1
	@echo

install-deps: ## Install LuaRocks dependencies
	@$(LUAROCKS_CMD) luassert
	@$(LUAROCKS_CMD) busted
	@$(LUAROCKS_CMD) nlua

lint: ## Lint using StyLua
	@echo -e "Running StyLua...\n"
	@stylua .
	@echo

test: install-deps ## Run tests with busted
	@echo -e "Running tests...\n"
	@busted spec
	@echo
# vim: set ts=4 sts=4 sw=0 noet ai si sta:
