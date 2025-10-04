CMD = nvim --clean --headless

RETAB_CMD = $(CMD) -c 'set ts=4 sts=4 sw=4 et ai si sta' -c '%retab!' -c 'w' -c 'qa!' doc/project-nvim.txt
TAGS_CMD = $(CMD) -c 'helptags doc/' -c 'qa!'

helptags:
	$(RETAB_CMD) > /dev/null 2>&1
	$(TAGS_CMD)

doc/project-nvim.txt: helptags

clean:
	rm -rf doc/tags

all: helptags

.PHONY: \
	all \
	clean \
	helptags
