PREFIX = $(HOME)/.local
INSTALL_BIN_DIR = $(DESTDIR)$(PREFIX)/bin
INSTALL_LIB_DIR = $(DESTDIR)$(PREFIX)/lib/ttytok
INSTALL_PT_DIR = $(DESTDIR)$(PREFIX)/lib/piratetok
INSTALL_SHARE_DIR = $(HOME)/.local/share/ttytok

SCRIPTS = ttytok.sh connector.sh discover.sh userselect.sh watchers.sh

.PHONY: install uninstall deps

deps:
	@if command -v bpkg >/dev/null 2>&1; then \
		bpkg install PirateTok/live-sh; \
	else \
		echo "fetching piratetok.sh from github..."; \
		mkdir -p $(INSTALL_PT_DIR); \
		curl -fsSL https://raw.githubusercontent.com/PirateTok/live-sh/main/lib/piratetok.sh \
			-o $(INSTALL_PT_DIR)/piratetok.sh; \
	fi

install: deps
	mkdir -p $(INSTALL_BIN_DIR) $(INSTALL_LIB_DIR) $(INSTALL_SHARE_DIR)
	install -Dm755 ttytok.sh $(INSTALL_BIN_DIR)/ttytok
	for script in $(SCRIPTS); do \
		install -Dm755 $$script $(INSTALL_LIB_DIR)/$$script; \
	done
	@test -f $(INSTALL_SHARE_DIR)/users || touch $(INSTALL_SHARE_DIR)/users

uninstall:
	rm -f $(INSTALL_BIN_DIR)/ttytok
	rm -rf $(INSTALL_LIB_DIR)
