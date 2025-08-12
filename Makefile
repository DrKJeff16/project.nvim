TAGS_CMD = -@nvim -c 'helptags doc/' -c 'qa!' --headless

helptags: doc/project-nvim.txt
	$(TAGS_CMD)

clean:
	-@rm -rf doc/tags

all: helptags

.PHONY: \
	all \
	clean \
	helptags
