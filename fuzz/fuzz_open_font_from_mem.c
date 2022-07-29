#include <stdint.h>
#include <stdbool.h>
#include <stdint.h> //uint8_t
#include <string.h> //memcpy

#include "SDL.h"
#include "SDL_ttf.h" //fuzzer target
#include "SDL_rwops.h" // necessary SDL_rwop data structure

#define PT_SIZE 12

bool lib_init = false;
SDL_Color color = {255, 255, 255};

void init_lib() {
    if (TTF_Init() == -1)
        exit(0);
    lib_init = true;
}


int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
    if (!lib_init)
        init_lib();

    // Create a new buffer of non-const fuzzer data
    uint8_t fuzz_data[size];
    memcpy(fuzz_data, data, size);

    // Convert fuzzer data to an instance of SDL_RWops
    SDL_RWops* src = SDL_RWFromMem(fuzz_data, size);
    if (!src) // Unable to create a RWops instance
        return 0;

    // Call target to convert our fuzzer input into an SDL surface
    TTF_Font *font = TTF_OpenFontRW(src, 1, PT_SIZE);

    // Try using font
    SDL_Surface *surface = TTF_RenderText_Solid(font, "Fuzzing is fun", color); 

    // Cleanup
    if (surface)
        SDL_FreeSurface(surface);
    if (font)
        TTF_CloseFont(font);

    return 0;
}
