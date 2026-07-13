/* sdlttf_selftest — known-answer functional oracle for SDL3_ttf.
 *
 * AUTHORED test: upstream SDL_ttf ships NO automated test suite (no ctest/add_test;
 * examples/ are interactive apps), so this behavioral known-answer test exercises the
 * public API against a known font (DejaVu Sans, from fonts-dejavu-core) and asserts
 * observable results: font metadata, glyph metrics, measured string sizes, and rendered
 * surface contents. Built by mayhem/build.sh with NORMAL flags; run by mayhem/test.sh.
 *
 * Prints one line per case and a final "SELFTEST passed=P failed=F total=T" summary.
 * Exit code: 0 iff failed == 0.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <SDL3/SDL.h>
#include <SDL3_ttf/SDL_ttf.h>

static int n_pass = 0, n_fail = 0;

#define CHECK(name, cond) do { \
    if (cond) { printf("ok   %s\n", name); n_pass++; } \
    else      { printf("FAIL %s\n", name); n_fail++; } \
} while (0)

#define FONT_PATH "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"

int main(void)
{
    CHECK("TTF_Init succeeds", TTF_Init());

    TTF_Font *font = TTF_OpenFont(FONT_PATH, 24.0f);
    CHECK("open DejaVuSans.ttf at 24pt", font != NULL);
    if (!font) {
        printf("SELFTEST passed=%d failed=%d total=%d\n", n_pass, n_fail + 9, n_pass + n_fail + 9);
        return 1;
    }

    const char *family = TTF_GetFontFamilyName(font);
    CHECK("family name is 'DejaVu Sans'", family && strcmp(family, "DejaVu Sans") == 0);

    const char *style = TTF_GetFontStyleName(font);
    CHECK("style name is 'Book'", style && strcmp(style, "Book") == 0);

    int minx = 0, maxx = 0, miny = 0, maxy = 0, advance = 0;
    bool gm = TTF_GetGlyphMetrics(font, (Uint32)'A', &minx, &maxx, &miny, &maxy, &advance);
    CHECK("glyph metrics for 'A' sane", gm && advance > 0 && maxx > minx && maxy > miny);

    int fh = TTF_GetFontHeight(font);
    CHECK("font height positive", fh > 0);

    int w1 = 0, h1 = 0, w2 = 0, h2 = 0;
    bool sz1 = TTF_GetStringSize(font, "Hello", 0, &w1, &h1);
    CHECK("measure 'Hello': w>0, h==font height", sz1 && w1 > 0 && h1 == fh);

    bool sz2 = TTF_GetStringSize(font, "Hello, wider world", 0, &w2, &h2);
    CHECK("longer string measures strictly wider", sz2 && w2 > w1);

    int we = -1, he = -1;
    bool sze = TTF_GetStringSize(font, "", 0, &we, &he);
    CHECK("empty string measures zero width", sze && we == 0);

    SDL_Color white = { 255, 255, 255, 255 };
    SDL_Surface *surf = TTF_RenderText_Solid(font, "Hello", 0, white);
    CHECK("render 'Hello' returns a surface", surf != NULL);
    if (surf) {
        CHECK("rendered surface matches measured size", surf->w == w1 && surf->h == h1);
        /* Solid render is palettized 8-bit: nonzero bytes are glyph coverage. */
        int nonzero = 0;
        const Uint8 *px = (const Uint8 *)surf->pixels;
        for (int y = 0; y < surf->h; y++) {
            for (int x = 0; x < surf->w; x++) {
                if (px[y * surf->pitch + x] != 0) {
                    nonzero++;
                }
            }
        }
        CHECK("rendered surface has glyph coverage", nonzero > 0);
        SDL_DestroySurface(surf);
    } else {
        n_fail += 2;
    }

    /* Opening the same font from memory must work and agree on metadata. */
    size_t flen = 0;
    void *fdata = SDL_LoadFile(FONT_PATH, &flen);
    CHECK("load font file into memory", fdata != NULL && flen > 0);
    if (fdata) {
        SDL_IOStream *io = SDL_IOFromConstMem(fdata, flen);
        TTF_Font *memfont = io ? TTF_OpenFontIO(io, true, 16.0f) : NULL;
        const char *memfam = memfont ? TTF_GetFontFamilyName(memfont) : NULL;
        CHECK("open font from memory, same family", memfam && strcmp(memfam, "DejaVu Sans") == 0);
        if (memfont) {
            TTF_CloseFont(memfont);
        }
        SDL_free(fdata);
    } else {
        n_fail += 1;
    }

    /* Negative known-answer: garbage bytes must NOT open as a font. */
    static const char garbage[] = "this is definitely not a TrueType font, not even close";
    SDL_IOStream *gio = SDL_IOFromConstMem(garbage, sizeof(garbage));
    TTF_Font *gfont = gio ? TTF_OpenFontIO(gio, true, 12.0f) : NULL;
    CHECK("garbage buffer is rejected", gfont == NULL);
    if (gfont) {
        TTF_CloseFont(gfont);
    }

    TTF_CloseFont(font);
    TTF_Quit();

    printf("SELFTEST passed=%d failed=%d total=%d\n", n_pass, n_fail, n_pass + n_fail);
    return n_fail == 0 ? 0 : 1;
}
