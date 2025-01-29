include $(ROOTDIR)/rules.mk

PKG_NAME:=socat
PKG_VERSION:=1.8.0.2

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.bz2
PKG_SOURCE_URL:=http://www.dest-unreach.org/socat/download
PKG_HASH:=adc07a9c2723527cf6568d2fb96559794cf9c254a4bc2edd36f7f3789e9f7625

include $(INCLUDE_DIR)/package.mk

CONFIGURE_ARGS += \
	--disable-openssl \
	--disable-readline

$(eval $(call BuildPackage,socat))

romfs:
	$(INSTALL_DIR) $(ROMFSDIR)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/socat $(ROMFSDIR)/usr/bin/socat
