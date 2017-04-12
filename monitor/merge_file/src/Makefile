
LINC=C
INC_PATH=-I../include
LIB_PATH=-L../lib
BIN_PATH=../bin
MAC=-D_DEBUG_
S_LIB=-lxlog -lpthread

CC=g++
CPPFLAGS=-Wall -g $(INC_PATH) $(MAC)

TARGET=merge_file
all:$(TARGET)

merge_file:main.o merge_file.o config.o hash.o merge_file_thread.o
	$(CC) -g -o $@ $^ $(LIB_PATH) $(S_LIB)
	mv $@ $(BIN_PATH)
	rm -f *.o
	@printf "\033[32mMERGE_FILE FINISH\033[0m\n"
clean:
	rm -f *.o
