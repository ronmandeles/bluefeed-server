# Shortcuts. HOST is the folder name under hosts/ (default: bluefeed-server).
#
#   make iso                 build the self-installing USB image for HOST
#   make iso HOST=other      ...for another server
#   make check               run the automated security test in VMs
HOST ?= bluefeed-server

.PHONY: iso check

iso:
	nix build .#$(HOST)-installer-iso -o result-iso-$(HOST)
	@echo
	@echo "USB image: $$(ls result-iso-$(HOST)/iso/*.iso)"
	@echo "Write it to a USB stick with balenaEtcher (or dd), then boot the server from it."

check:
	nix build -L .#checks.x86_64-linux.$(HOST)
