CC ?= gcc
WARNINGS = -Wall -Wextra

ifdef GPIO
CFLAGS ?= $(WARNINGS) -std=c11 -DGPIO=$(GPIO)
else
CFLAGS ?= $(WARNINGS) -std=c99
endif

# Optional coverage instrumentation: `make COVERAGE=1`
ifdef COVERAGE
CFLAGS += --coverage -O0 -g
LDFLAGS += --coverage
endif

BINDIR = /usr/local/bin
MANDIR = /usr/local/share/man/man1

UNAME_S := $(shell uname -s)

ifeq ($(UNAME_S),Darwin)
LINK_LIBS = -framework OpenAL
else
ifdef GPIO
LINK_LIBS = -lm
else
LINK_LIBS = -lopenal -lm
endif
endif

ifdef GPIO
SRCS = mbeep.c text.c sound.c patterns.c tiny_gpio.c
else
SRCS = mbeep.c text.c sound.c patterns.c
endif

HDRS = text.h sound.h patterns.h
ifdef GPIO
HDRS += tiny_gpio.h
endif

.PHONY: all clean distclean install

all : mbeep mbeep.1

mbeep : $(SRCS) $(HDRS)
	$(CC) $(CFLAGS) -o mbeep $(SRCS) $(LDFLAGS) $(LINK_LIBS)

# Generate the man page source from the binary itself.
mbeep.1 : mbeep
	./mbeep --man-page > mbeep.1

install : mbeep mbeep.1
	cp mbeep $(BINDIR)/
	mkdir -p $(MANDIR)
	cp mbeep.1 $(MANDIR)/

clean :
	rm -f mbeep mbeep.1 *.o *.gcno *.gcda *.gcov coverage.xml

distclean : clean
	rm -f $(BINDIR)/mbeep $(MANDIR)/mbeep.1
