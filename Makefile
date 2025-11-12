CMD = nvim --clean --headless

RETAB_CMD = $(CMD) -c 'set ts=4 sts=4 sw=4 et' -c '%retab!' -c 'w' -c 'qa!' doc/project-nvim.txt
TAGS_CMD = $(CMD) -c 'helptags doc/' -c 'qa!'

all:
	@$(MAKE) lint
	@$(MAKE) helptags

helptags:
	$(RETAB_CMD) > /dev/null 2>&1
	$(TAGS_CMD) > /dev/null 2>&1

doc/project-nvim.txt: helptags

lint:
	@stylua .

clean:
	rm -rf doc/tags

.PHONY: \
	all \
	clean \
	helptags \
	lint
