include $(ROOTDIR)/rules.mk

PKG_NAME:=sqlite
PKG_VERSION:=3480000

PKG_SOURCE:=$(PKG_NAME)-autoconf-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://www.sqlite.org/2025/
PKG_HASH:=ac992f7fca3989de7ed1fe99c16363f848794c8c32a158dafd4eb927a2e02fd5

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-autoconf-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

CONFIGURE_ARGS += \
	$(if $(LIBS_BUILD_SHARED),--disable-static,--enable-static) \
	$(if $(LIBS_BUILD_SHARED),--enable-shared,--disable-shared) \
	--disable-readline \
	--disable-dynamic-extensions \
	--disable-fts3 \
	--disable-fts4 \
	--disable-fts5 \
	--disable-json1 \
	--disable-rtree \
	--disable-session \
	--disable-debug \
	--disable-static-shell

$(eval $(call BuildPackage,sqlite))

romfs:
	$(INSTALL_DIR) $(ROMFSDIR)/lib
	$(CP) $(PKG_INSTALL_DIR)/lib/libsqlite3.so* $(ROMFSDIR)/lib/
