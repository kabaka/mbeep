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

.PHONY: all clean distclean install test coverage

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

# Run the end-to-end test suite (headless .wav generation only).
test : mbeep
	MBEEP=./mbeep tests/run_tests.sh

# Rebuild with instrumentation, run the full suite (including the audio-device
# playback path via openal-soft's null backend), and write a Cobertura report.
# Requires gcovr. On Linux this uses ALSOFT_DRIVERS=null so no sound hardware
# is needed; it is harmlessly ignored by Apple's OpenAL on macOS.
coverage :
	$(MAKE) clean
	$(MAKE) COVERAGE=1
	MBEEP=./mbeep MBEEP_PLAYBACK=1 ALSOFT_DRIVERS=null tests/run_tests.sh
	gcovr --root . --exclude tests --cobertura coverage.xml --print-summary

clean :
	rm -f mbeep mbeep.1 *.o *.gcno *.gcda *.gcov coverage.xml

distclean : clean
	rm -f $(BINDIR)/mbeep $(MANDIR)/mbeep.1
