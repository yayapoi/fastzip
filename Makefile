# Set this to zero to compile without the Intel fast deflate
# ...Also means you don't need YASM
# WITH_INTEL=0
# BENCHMARK=1

ifeq ($(HOST),)

ifeq ($(OS),Windows_NT)
  HOST = windows
  CMDEXE = 1
else
  UNAME_S := $(shell uname -s)
  UNAME_N := $(shell uname -n)
  ifeq ($(UNAME_S),Linux)
    HOST = linux
  endif
  ifeq ($(UNAME_S),Darwin)
    HOST = apple
  endif
endif

endif

# Basic settings
LD = $(CXX)
YASM = yasm
OBJDIR = obj
SRCDIR = src
CFLAGS = -g -O2 -I$(SRCDIR)/igzip -I$(SRCDIR)/infozip -I$(SRCDIR)/openssl/include -Wno-deprecated-declarations -Wno-unused-result
CFLAGS += -Wall -Wno-unused-variable -Wno-unused-function
ASMFLAGS=-I $(SRCDIR)/igzip
LIBS = -lcrypto
TARGET = fastzip

ifeq ($(BENCHMARK),1)
  CFLAGS += -DDO_BENCHMARK -I/usr/local/include
  LIBS += -lbenchmark
  LDFLAGS += -L/usr/local/lib
endif

ifeq ($(HOST),windows)
  CFLAGS += -mno-ms-bitfields -I$(SRCDIR)/mingw-std-threads
  ASMFLAGS += -DWIN_CC=1
  LIBS += -lgdi32 
  LDFLAGS += -Lprebuilt/win -static
  TARGET := $(TARGET).exe
  OBJDIR = winobj
  ifeq ($(WITH_INTEL),)
    WITH_INTEL=0
  endif
else
  ifeq ($(WITH_INTEL),)
    WITH_INTEL=1
  endif
endif

ifeq ($(HOST),apple)
  ASMFLAGS += -f macho64
else
  ASMFLAGS += -f elf64
endif

ifeq ($(HOST),linux)
  LDFLAGS+=-pthread
endif

CXXFLAGS=$(CFLAGS) -std=c++11

#CXX=g++
#CC=gcc
LD=$(CXX)

OBJFILES= \
  $(OBJDIR)/fastzip_keystore.o \
  $(OBJDIR)/inflate.o \
  $(OBJDIR)/main.o \
  $(OBJDIR)/utils.o \
  $(OBJDIR)/fastzip.o \
  $(OBJDIR)/asn.o \
  $(OBJDIR)/crypto.o \
  $(OBJDIR)/crc32/Crc32.o \
  $(OBJDIR)/infozip.o \
  $(OBJDIR)/infozip/deflate.o \
  $(OBJDIR)/infozip/trees.o

ifeq ($(WITH_INTEL),1)
  OBJFILES += \
    $(OBJDIR)/igzip/igzip1c_body.o \
    $(OBJDIR)/igzip/igzip1c_finish.o \
    $(OBJDIR)/igzip/c_code/common.o \
    $(OBJDIR)/igzip/c_code/crc.o \
    $(OBJDIR)/igzip/c_code/crc_utils.o \
    $(OBJDIR)/igzip/c_code/hufftables_c.o \
    $(OBJDIR)/igzip/bitbuf2.o \
    $(OBJDIR)/igzip/crc.o \
    $(OBJDIR)/igzip/huffman.o \
    $(OBJDIR)/igzip/hufftables.o \
    $(OBJDIR)/igzip/init_stream.o \
    $(OBJDIR)/igzip/utils.o

  CFLAGS += -DWITH_INTEL
endif

VERSION=_`date "+%y%m%d"`

all : $(TARGET)

dist :
	$(MAKE) -C .
	WITH_INTEL=0 HOST=windows PREFIX=x86_64-w64-mingw32- $(MAKE) -C .
	strip fastzip
	x86_64-w64-mingw32-strip fastzip.exe
	./fastzip fastzip$(VERSION).zip fastzip.exe=win/fastzip.exe fastzip=mac/fastzip


$(OBJDIR)/main.o : $(SRCDIR)/utils.h $(SRCDIR)/fastzip.h
$(OBJDIR)/fastzip.o : $(SRCDIR)/utils.h $(SRCDIR)/ziparchive.h $(SRCDIR)/fastzip.h $(SRCDIR)/crypto.h $(SRCDIR)/asn.h
$(OBJDIR)/crypto.o : $(SRCDIR)/crypto.h

# Not used currently
ifeq ($(CMDEXE),1)

clean:
	@del /Q /S $(OBJDIR)
	@del /Q /S $(TARGET)

$(OBJDIR)/%.o: $(SRCDIR)/%.c
	@if not exist "$(@D)" @mkdir "$(@D)"
	$(CC) -c $(CFLAGS) $< -o $@

$(OBJDIR)/%.o: $(SRCDIR)/%.cpp
	@if not exist "$(@D)" @mkdir "$(@D)"
	$(CXX) -c $(CXXFLAGS) $< -o $@

$(OBJDIR)/%.o: $(SRCDIR)/%.asm
	@if not exist "$(@D)" @mkdir "$(@D)"
	$(YASM) $(ASMFLAGS) $< -o $@

else

clean:
	rm -f $(OBJFILES) ${TARGET}

$(OBJDIR)/%.o: $(SRCDIR)/%.c
	@mkdir -p $(@D)
	$(PREFIX)$(CC) -c $(CFLAGS) $< -o $@

$(OBJDIR)/%.o: $(SRCDIR)/%.cpp
	@mkdir -p $(@D)
	$(PREFIX)$(CXX) -c $(CXXFLAGS) $< -o $@

$(OBJDIR)/%.o: $(SRCDIR)/%.asm
	@mkdir -p $(@D)
	$(YASM) $(ASMFLAGS) $< -o $@

endif

$(TARGET): $(OBJFILES) $(LIBMODS) $(DEPS)
	$(PREFIX)$(LD) -o $(TARGET) $(OBJFILES) $(LIBMODS) $(LIBS) $(LDFLAGS)

