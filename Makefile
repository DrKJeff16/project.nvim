CMD = nvim --clean --headless

RETAB_ARGS = -c 'set ts=4 sts=4 sw=4 et ai si sta' -c '%retab!' -c 'w' -c 'qa!' doc/project-nvim.txt
TAGS_ARGS = -c 'helptags doc/' -c 'qa!'

helptags:
	$(CMD) $(RETAB_ARGS) > /dev/null 2>&1
	$(CMD) $(TAGS_ARGS)

doc/project-nvim.txt: helptags

clean:
	rm -rf doc/tags

all: helptags

.PHONY: \
	all \
	clean \
	helptags
