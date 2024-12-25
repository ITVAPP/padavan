THISDIR = $(shell pwd)
SRC_NAME = ipset-7.11

all: config_test
	$(MAKE) -C $(SRC_NAME)

config_test:
	( if [ -f ./config_done ]; then \
		echo "the same configuration"; \
	else \
		make configure && touch config_done; \
	fi )

configure:
	( cd $(SRC_NAME) ; \
	./configure \
		--prefix=/usr \
		--with-kmod=no \
		--disable-shared \
		--enable-static \
		--without-mnl \     # 关键修改在这里
		CFLAGS="-O2" \
		LDFLAGS="" \
		--host=$(HOST_TARGET) \
		--build=$(HOST_BUILD) ; \
	)

clean:
	if [ -f $(SRC_NAME)/Makefile ] ; then \
		$(MAKE) -C $(SRC_NAME) distclean ; \
	fi ; \
	rm -f config_done

romfs:
	$(ROMFSINST) $(THISDIR)/$(SRC_NAME)/src/ipset /sbin/ipset

.PHONY: all configure config_test clean romfs
