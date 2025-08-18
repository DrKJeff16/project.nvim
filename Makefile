helptags: doc/project-nvim.txt
	nvim --clean -c 'set ts=4 sts=4 sw=4 et ai si sta' -c '%retab!' -c 'wq' --headless doc/project-nvim.txt > /dev/null 2>&1
	nvim --clean -c 'helptags doc/' -c 'qa!' --headless

clean:
	-@rm -rf doc/tags

all: helptags

.PHONY: \
	all \
	clean \
	helptags
