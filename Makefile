CMD = nvim --clean --headless

RETAB_CMD = $(CMD) -c 'set ts=4 sts=4 sw=4 et' -c '%retab!' -c 'w' -c 'qa!' doc/project-nvim.txt
TAGS_CMD = $(CMD) -c 'helptags doc/' -c 'qa!'

all:
	@$(MAKE) retab
	@$(MAKE) helptags

test:
	@./scripts/deps.sh mini
	@nvim --version | head -n 1
	@nvim --headless --noplugin -u ./scripts/minimal_init.lua \
		-c "lua require('mini.test').setup()" \
		-c "lua MiniTest.run({ execute = { reporter = MiniTest.gen_reporter.stdout({ group_depth = 2 }) } })"

retab:
	@echo -e "\nRetabbing helpdocs...\n"
	@$(RETAB_CMD) > /dev/null 2>&1
	@echo

helptags:
	@echo -e "\nGenerating helptags...\n"
	@$(TAGS_CMD) > /dev/null 2>&1
	@echo

doc/project-nvim.txt:
	@$(MAKE) retab
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
	helptags \
	lint \
	retab \
	test
