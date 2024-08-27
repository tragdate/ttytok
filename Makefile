MAIN_SCRIPT=ttytok.sh
TOOL=connector
SRC=connector_bin/src/main.rs
TARGET_DIR=connector_bin/target/release
INSTALL_BIN_DIR=$(DESTDIR)/usr/local/bin
INSTALL_LIB_DIR=$(DESTDIR)/usr/local/lib/ttytok
INSTALL_SHARE_DIR=$(HOME)/.local/share/ttytok
SCRIPTS=userselect.sh watchers.sh
EXTRAS=users cookies

all: $(TARGET_DIR)/$(TOOL)

$(TARGET_DIR)/$(TOOL):
	cargo build --release --manifest-path=connector_bin/Cargo.toml
	mkdir -p $(INSTALL_SHARE_DIR)
	for extra in $(EXTRAS); do \
		install -Dm644 $$extra $(INSTALL_SHARE_DIR)/$$extra; \
	done

install: $(TARGET_DIR)/$(TOOL)
	./install_req.sh
	mkdir -p $(INSTALL_LIB_DIR)
	install -Dm755 $(MAIN_SCRIPT) $(INSTALL_BIN_DIR)/ttytok
	install -Dm755 $(TARGET_DIR)/$(TOOL) $(INSTALL_LIB_DIR)/$(TOOL)
	for script in $(SCRIPTS); do \
		install -Dm755 $$script $(INSTALL_LIB_DIR)/$$script; \
	done

clean:
	cargo clean --manifest-path=connector_bin/Cargo.toml


uninstall:
	rm -f $(INSTALL_BIN_DIR)/ttytok
	rm -f $(INSTALL_LIB_DIR)/$(TOOL)
	for script in $(SCRIPTS); do \
		rm -f $(INSTALL_LIB_DIR)/$$script; \
	done
	for extra in $(EXTRAS); do \
		rm -f $(INSTALL_LIB_DIR)/$$extra; \
	done
	rm -rf $(INSTALL_LIB_DIR)
