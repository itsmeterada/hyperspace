# Makefile for Hyperspace SDL2 port

# Compiler
CC = gcc

# Platform detection
ifeq ($(OS),Windows_NT)
    # Windows (MinGW/MSYS2)
    CFLAGS = -Wall -O2 -std=c99 $(shell sdl2-config --cflags 2>/dev/null || echo -I/mingw64/include/SDL2)
    LDFLAGS = -lmingw32 -lSDL2main -lSDL2 -lm
    TARGET = hyperspace.exe
else
    UNAME_S := $(shell uname -s)
    ifeq ($(UNAME_S),Darwin)
        # macOS
        CFLAGS = -Wall -O2 -std=c99 $(shell sdl2-config --cflags)
        LDFLAGS = $(shell sdl2-config --libs) -lm
        TARGET = hyperspace
    else
        # Linux
        CFLAGS = -Wall -O2 -std=c99 $(shell sdl2-config --cflags)
        LDFLAGS = $(shell sdl2-config --libs) -lm
        TARGET = hyperspace
    endif
endif

# Source files
SRCS = hyperspace_sdl2.c
OBJS = $(SRCS:.c=.o)

# Build target
all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(OBJS) -o $(TARGET) $(LDFLAGS)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJS) $(TARGET)

run: $(TARGET)
	./$(TARGET)

.PHONY: all clean run
