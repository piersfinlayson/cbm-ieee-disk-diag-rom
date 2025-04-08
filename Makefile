# 6502 file definitions
SOURCE = diag_x040.s
OBJ_F000 = diag_x040_f000.o
OBJ_D000 = diag_x040_d000.o
BIN_F000 = diag_x040_f000.bin
BIN_D000 = diag_x040_d000.bin

# 6504 definitions
SOURCE_6504 = diag_x040_6504.s
OBJ_6504 = diag_x040_6504.o
BIN_6504 = diag_x040_6504.bin

CA65_OPTS = -W1

# Default target
all: $(BIN_F000) $(BIN_D000)

# Build 6504 binary
$(OBJ_6504): $(SOURCE_6504)
	ca65 $(CA65_OPTS) $(SOURCE_6504) -o $(OBJ_6504)

$(BIN_6504): $(OBJ_6504)
	ld65 -t none -o $(BIN_6504) $(OBJ_6504)

# F000 version
$(OBJ_F000): $(SOURCE) $(BIN_6504)
	ca65 $(CA65_OPTS) $(SOURCE) -o $(OBJ_F000) -D F000_BUILD

# D000 version
$(OBJ_D000): $(SOURCE) $(BIN_6504)
	ca65 $(CA65_OPTS) $(SOURCE) -o $(OBJ_D000) -D D000_BUILD

# Link versions
$(BIN_F000): $(OBJ_F000) diag_x040_f000.cfg
	ld65 -C diag_x040_f000.cfg -o $(BIN_F000) $(OBJ_F000)

$(BIN_D000): $(OBJ_D000) diag_x040_d000.cfg
	ld65 -C diag_x040_d000.cfg -o $(BIN_D000) $(OBJ_D000)

clean:
	rm -f $(OBJ_F000) $(OBJ_D000) $(BIN_F000) $(BIN_D000) $(OBJ_6504) $(BIN_6504)

.PHONY: all clean