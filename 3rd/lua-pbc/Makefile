CC = gcc
CFLAGS = -O2 -Wall -fPIC
TARGET = protobuf.so
PREFIX = /usr/local
PBC_LDFLAGS = --shared
LUA_INCLUDE_DIR =   $(PREFIX)/include

.PHONY : all clean

OBJS = context.o varint.o array.o pattern.o register.o proto.o map.o alloc.o rmessage.o wmessage.o bootstrap.o stringpool.o decode.o pbc-lua.o

.c.o:
	$(CC) -c $(CFLAGS) $(CPPFLAGS) -I$(LUA_INCLUDE_DIR) -I. -o $@ $<

$(TARGET): $(OBJS)
	$(CC) $(LDFLAGS) $(PBC_LDFLAGS) -o $@ $(OBJS)

all : $(TARGET)

clean:
	rm -f *.o $(TARGET)
