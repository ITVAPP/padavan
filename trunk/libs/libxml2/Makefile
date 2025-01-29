include $(ROOTDIR)/rules.mk

PKG_NAME:=libxml2
PKG_VERSION:=2.13.5

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.xz
PKG_SOURCE_URL:=@GNOME/libxml2/$(basename $(PKG_VERSION))
PKG_HASH:=74fc163217a3964257d3be39af943e08861263c4231f9ef5b496b6f6d4c7b2b6

include $(INCLUDE_DIR)/package.mk

CONFIGURE_ARGS += \
	--enable-static \
	--disable-shared \
	$(if $(CONFIG_IPV6),--enable-ipv6,--disable-ipv6) \
	--without-catalog \
	--without-debug \
	--without-docbook \
	--without-ftp \
	--without-http \
	--without-legacy \
	--without-lzma \
	--without-pattern \
	--without-push \
	--without-python \
	--without-readline \
	--without-regexps \
	--without-iconv \
	--without-iso8859x \
	--with-c14n \
	--with-html \
	--with-output \
	--with-reader \
	--with-sax1 \
	--with-schemas \
	--with-threads \
	--with-tree \
	--with-valid \
	--with-writer \
	--with-xinclude \
	--with-xpath \
	--with-xptr \
	--with-zlib=$(STAGING_DIR)

$(eval $(call BuildPackage,libxml2))

romfs:
