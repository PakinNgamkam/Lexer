
#include "lexer.h"
#include <stdio.h>

int main(int argc, char *argv[]) {
    // Check for the correct number of command-line arguments
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <filename>\n", argv[0]);
        return 1;
    }

    // Initialize the lexer with the provided file name
    lexer_init(argv[1]);

    // Process the lexer's work
    lexer_output();

    return 0;  // Return with success
}
