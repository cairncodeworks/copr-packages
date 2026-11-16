# Entry point for COPR's "make srpm" SCM build method.
#
# COPR clones this repository, then runs the following with the working
# directory set to the package subdirectory configured in the COPR package
# settings:
#
#   make -f <repo>/.copr/Makefile srpm outdir=<dir> spec=<spec>
#
# The target runs with root privileges inside a mock chroot of the COPR
# builder host's Fedora release, and that chroot is allowed to use the
# network. That is what makes it possible to download sources here instead of
# keeping them in the repository.

REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)

# COPR always passes `spec`, but fall back to the single spec file in the
# current directory so the target can also be run by hand.
SPEC ?= $(if $(spec),$(spec),$(notdir $(wildcard *.spec)))

.PHONY: srpm
srpm:
	dnf -y install --setopt=install_weak_deps=False \
	    curl jq rpmdevtools >/dev/null
	sh $(REPO_ROOT)/scripts/srpm.sh --spec '$(SPEC)' --outdir '$(outdir)'
