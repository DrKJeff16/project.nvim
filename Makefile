helptags: doc/project-nvim.txt
	nvim --clean -c 'helptags doc/' -c 'qa!' --headless

clean:
	-@rm -rf doc/tags

all: helptags

.PHONY: \
	all \
	clean \
	helptags
