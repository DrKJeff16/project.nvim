CMD = -@nvim --clean --headless

RETAB_ARGS = -c 'set ts=4 sts=4 sw=4 et ai si sta' -c '%retab!' -c 'wq!' doc/project-nvim.txt
TAGS_ARGS = -c 'helptags doc/' -c 'qa!'

helptags: doc/project-nvim.txt
	$(CMD) $(RETAB_ARGS) > /dev/null 2>&1
	$(CMD) $(TAGS_ARGS)

clean:
	-@rm -rf doc/tags

all: helptags

.PHONY: \
	all \
	clean \
	helptags
