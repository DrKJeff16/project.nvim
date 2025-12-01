CMD = nvim --clean --headless

RETAB_CMD = $(CMD) -c 'set ts=4 sts=4 sw=4 et' -c '%retab!' -c 'w' -c 'qa!' doc/project-nvim.txt
TAGS_CMD = $(CMD) -c 'helptags doc/' -c 'qa!'

all:
	@$(MAKE) retab
	@$(MAKE) helptags

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
	retab
