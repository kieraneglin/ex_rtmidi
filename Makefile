MIX = mix

# These flags are what need to change to compile based on OS (ie: to add Linux/Windows support)
CFLAGS = -O3 -Wall -D__MACOSX_CORE__ -std=c++11
RTMIDI_FLAGS = -framework CoreMIDI -framework CoreAudio -framework CoreFoundation

ERLANG_PATH = $(shell erl -eval 'io:format("~s", [lists:concat([code:root_dir(), "/erts-", erlang:system_info(version), "/include"])])' -s init stop -noshell)
CFLAGS += -I$(ERLANG_PATH)
RTMIDI_PATH = src/rtmidi

# This is a magic incantation from the internet but I imagine it also needs to change to add Linux/Windows support
ifneq ($(OS),Windows_NT)
	CFLAGS += -fPIC

	ifeq ($(shell uname),Darwin)
		LDFLAGS = -dynamiclib -undefined dynamic_lookup
	endif
endif

.PHONY: all ex_rtmidi_output clean

priv/ex_rtmidi_output.so: src/ex_rtmidi_output.cpp
	$(CC) $(CFLAGS) -shared $(LDFLAGS) -o $@ src/ex_rtmidi_output.cpp $(RTMIDI_PATH)/RtMidi.cpp $(RTMIDI_FLAGS)

priv/ex_rtmidi_input.so: src/ex_rtmidi_input.cpp
	$(CC) $(CFLAGS) -shared $(LDFLAGS) -o $@ src/ex_rtmidi_input.cpp $(RTMIDI_PATH)/RtMidi.cpp $(RTMIDI_FLAGS)

clean:
	$(MIX) clean
	$(MAKE) -C $(RTMIDI_PATH) clean
	$(RM) priv/ex_rtmidi_output.so
	$(RM) priv/ex_rtmidi_input.so
