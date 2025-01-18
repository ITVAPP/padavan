THISDIR := $(shell pwd)

all: extra_test
	@echo "frp build done!"

extra_test:
	( if [ ! -f frpc ]; then \
		echo "Error: frpc not found in current directory"; \
		exit 1; \
	fi )

clean:
	#rm -rf frpc

romfs:
ifeq ($(CONFIG_FIRMWARE_INCLUDE_FRPC),y)
	$(ROMFSINST) -p +x $(THISDIR)/frpc /usr/bin/frpc
endif
	$(ROMFSINST) -p +x $(THISDIR)/frp.sh /usr/bin/frp.sh
	$(ROMFSINST) /etc_ro/frp_script.sh
