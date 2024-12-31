# Makefile

CWD := $(shell pwd)

.PHONY: all clean pub F90 f2py src_utils src_matrix src_dft src_hp basic flatsky curvedsky

# Variables
F90_DIR := F90
WRAP_DIR := wrap

# Functions
define makeF90
    @echo "---- $1 ----"
    @cd $(F90_DIR)/$1 && \
    $(MAKE) -f Makefile clean && \
    $(MAKE) -f Makefile && \
    $(MAKE) -f Makefile install && \
    $(MAKE) -f Makefile clean && \
    cd $(CWD)
endef

define makef2py
    @echo "---- $1 ----"
    @cd $1/src/ && \
    ./makefile.sh all && \
    cd $(CWD)
endef

all: F90 f2py

F90: src_utils src_matrix src_dft src_hp

f2py: basic flatsky curvedsky
src_utils:
	$(call makeF90,src_utils)
src_matrix:
	$(call makeF90,src_matrix)
src_dft:
	$(call makeF90,src_dft)
src_hp:
	$(call makeF90,src_hp)
basic:
	$(call makef2py,basic)

flatsky:
	$(call makef2py,flatsky)
curvedsky:
	$(call makef2py,curvedsky)
clean:
	rm -rf $(WRAP_DIR)/*.so $(WRAP_PY2_DIR)/*.so $(F90_DIR)/lib/*.a $(F90_DIR)/mod/*.mod

