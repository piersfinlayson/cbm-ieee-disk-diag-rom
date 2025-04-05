# File definitions
SOURCE = diag_x040.s
OBJ = diag_x040.o
BIN_F000 = diag_x040_f000.bin
BIN_D000 = diag_x040_d000.bin

# Default target - build both ROMs
all: $(BIN_F000) $(BIN_D000)

# Compile source to object file
$(OBJ): $(SOURCE)
	ca65 $(SOURCE) -o $(OBJ)

# Link F000 version
$(BIN_F000): $(OBJ) diag_x040_f000.cfg
	ld65 -C diag_x040_f000.cfg -o $(BIN_F000) $(OBJ)

# Link D000 version
$(BIN_D000): $(OBJ) diag_x040_d000.cfg
	ld65 -C diag_x040_d000.cfg -o $(BIN_D000) $(OBJ)

# Clean generated files
clean:
	rm -f $(OBJ) $(BIN_F000) $(BIN_D000)

# Force these targets to run even if files with these names exist
.PHONY: all clean