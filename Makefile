SHELL   := /bin/bash

# Maintainer makefile for Octave Doctest
#
# SPDX-License-Identifier: FSFAP
#
# Copyright 2015 Oliver Heimlich
# Copyright 2015 Michael Walter
# Copyright 2015-2017, 2019 Colin B. Macdonald
# Copyright 2016 Carnë Draug
# Copyright 2019 Mike Miller
# Copyright 2019 Andrew Janke
# Copyright 2019 Manuel Leonhardt
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

TAR := $(shell which gtar 2>/dev/null || echo tar)

PACKAGE := $(shell grep "^Name: " DESCRIPTION | cut -f2 -d" ")
VERSION := $(shell grep "^Version: " DESCRIPTION | cut -f2 -d" ")

BUILD_DIR := tmp
MATLAB_PKG := ${BUILD_DIR}/${PACKAGE}-matlab-${VERSION}
MATLAB_PKG_ZIP := ${MATLAB_PKG}.zip
OCTAVE_RELEASE := ${BUILD_DIR}/${PACKAGE}-${VERSION}
OCTAVE_RELEASE_TARBALL := ${BUILD_DIR}/${PACKAGE}-${VERSION}.tar.gz

INSTALLED_PACKAGE := ~/octave/${PACKAGE}-${VERSION}/packinfo/DESCRIPTION
HTML_DIR := ${BUILD_DIR}/${PACKAGE}-html
HTML_TARBALL := ${HTML_DIR}.tar.gz

OCTAVE ?= octave
MKOCTFILE ?= mkoctfile -Wall
MATLAB ?= matlab

TEST_CODE=ver(), success = doctest({'doctest', 'test/', 'test/examples/'}); exit(~success);
# run tests twice so we can see some output
BIST_CODE=cd('test'); pwd(), test('bist'); success = test('bist'); exit(~success);


.PHONY: help clean install test test-interactive dist html matlab_test matlab_pkg

help:
	@echo Available rules:
	@echo "  clean              clean all temporary files"
	@echo "  install            install package in Octave"
	@echo "  test               run tests with Octave"
	@echo "  test-interactive   run tests with Octave in interactive mode"
	@echo "  test-bist          run additional tests with Octave"
	@echo "  dist               create Octave package (${OCTAVE_RELEASE_TARBALL})"
	@echo "  html               create Octave Forge html (${HTML_TARBALL})"
	@echo "  release            create both tarballs and md5 sums"
	@echo
	@echo "  matlab_test        run tests with Matlab"
	@echo "  matlab_pkg         create Matlab package (${MATLAB_PKG_ZIP})"


GIT_DATE   := $(shell git show -s --format=\%ci)
# Follows the recommendations of https://reproducible-builds.org/docs/archives
define create_tarball
$(shell set -o pipefail; cd $(dir $(1)) \
    && find $(notdir $(1)) -print0 \
    | LC_ALL=C sort -z \
    | $(TAR) c --mtime="$(GIT_DATE)" \
            --owner=root --group=root --numeric-owner \
            --no-recursion --null -T - -f - \
    | gzip -9n > "$(2)")
endef

%.tar.gz: %
	$(call create_tarball,$<,$(notdir $@))

%.zip: %
	cd "$(BUILD_DIR)" ; zip -9qr - "$(notdir $<)" > "$(notdir $@)"

$(OCTAVE_RELEASE): .git/index | $(BUILD_DIR)
	@echo "Creating package version $(VERSION) release ..."
	-$(RM) -r "$@"
	git archive --format=tar --prefix="$@/" HEAD | $(TAR) -x
	$(RM) "$@/README.matlab.md" \
	      "$@/.gitignore" \
	      "$@/.travis.yml" \
	      "$@/.mailmap"
	$(RM) -r "$@/util"
	chmod -R a+rX,u+w,go-w "$@"

$(HTML_DIR): install | $(BUILD_DIR)
	@echo "Generating HTML documentation. This may take a while ..."
	-$(RM) -r "$@"
	$(OCTAVE) --no-window-system --silent \
	  --eval "pkg load generate_html; " \
	  --eval "pkg load $(PACKAGE);" \
	  --eval "options = get_html_options ('octave-forge');" \
	  --eval "generate_package_html ('${PACKAGE}', '${HTML_DIR}', options)"
	chmod -R a+rX,u+w,go-w $@

dist: $(OCTAVE_RELEASE_TARBALL)
html: $(HTML_TARBALL)
md5: $(OCTAVE_RELEASE_TARBALL) $(HTML_TARBALL)
	@md5sum $^

release: md5
	@echo "Upload @ https://sourceforge.net/p/octave/package-releases/new/"
	@echo "*After review*, an Octave-Forge admin will tag this with:"
	@echo "    git tag -a v$(VERSION) -m \"Version $(VERSION)\""


# TODO: more matlab subdirs
${BUILD_DIR} ${MATLAB_PKG}/private:
	mkdir -p "$@"

clean:
	rm -rf "${BUILD_DIR}"

test:
	${OCTAVE} --path ${CURDIR}/inst --eval "${TEST_CODE}"

test-interactive:
	script --quiet --command "${OCTAVE} --path ${CURDIR}/inst --eval \"${TEST_CODE}\"" /dev/null

test-bist:
	${OCTAVE} --path ${CURDIR}/inst --eval "${BIST_CODE}"

## Install in Octave (locally)
install: ${INSTALLED_PACKAGE}
${INSTALLED_PACKAGE}: ${OCTAVE_RELEASE_TARBALL}
	$(OCTAVE) --silent --eval "pkg install $<"


## Matlab packaging
matlab_pkg: $(MATLAB_PKG_ZIP)

${MATLAB_PKG}: | $(BUILD_DIR) ${MATLAB_PKG}/private
	$(OCTAVE) --path ${CURDIR}/util --silent --eval \
		"convert_comments('inst/', '', '../${MATLAB_PKG}/')"
	cp -a inst/private/*.m ${MATLAB_PKG}/private/
	cp -a COPYING ${MATLAB_PKG}/
	cp -a CONTRIBUTORS ${MATLAB_PKG}/
	cp -a NEWS ${MATLAB_PKG}/
	cp -a README.matlab.md ${MATLAB_PKG}/
	cp -a test ${MATLAB_PKG}/

matlab_test: matlab_pkg
	cd "${MATLAB_PKG}"; ${MATLAB} -nojvm -nodisplay -nosplash -r "${TEST_CODE}"
