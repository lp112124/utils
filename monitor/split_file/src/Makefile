
LINC=C
INC_PATH=-I../include
LIB_PATH=-L../lib
BIN_PATH=../bin
MAC=-D_DEBUG_
S_LIB=-lxlog

CC=g++
CPPFLAGS=-Wall -g $(INC_PATH) $(MAC)

TARGET=split_file
all:$(TARGET)

split_file:main.o extract_file.o config.o
	$(CC) -g -o $@ $^ $(LIB_PATH) $(S_LIB)
	mv $@ $(BIN_PATH)
	rm -f *.o
	@printf "\033[32mSPLIT_FILE FINISH\033[0m\n"
clean:
	rm -f *.o
