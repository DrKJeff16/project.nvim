helptags:
	nvim -c 'helptags doc/' -c 'qa!' --headless

distclean:
	rm -rf doc/tags

all: helptags

.PHONY: \
	helptags \
	distclean
