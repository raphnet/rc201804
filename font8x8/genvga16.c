#include <stdio.h>
#include <stdint.h>
#include <string.h>

#include "font8x8_basic.h"
#include "font8x8_ext_latin.h"

void render(char *bitmap, int val, FILE *out_fptr) {
	static unsigned char tmp[9][9];
    int x,y,n;
    int set;

	memset(tmp, 0, sizeof(tmp));

    for (y=0; y < 8; y++) {
        for (x=0; x < 8; x++) {
            set = bitmap[y] & 1 << x;

			if (set) {
				//tmp[y+1][x+1] = 2;
				if (val >= '0' && val <= '9') {
					tmp[y][x] = 15;
				} else if (val == '(' || val == ')' || val == ':' || val == '-') {
					tmp[y][x] = 8;
				} else {
					// Nice military style (camouflage)
					int thres = 3;
					if (val & 2)
						thres = 4;
					tmp[y][x] = y > thres ? 2 : 6;

				}
			}
		}
    }

	for (y=0; y<8; y++)
	{
		for (n=0; n<4; n++) {
			uint8_t b = 1<<n;
			uint8_t row = 0;
			for (x=0; x<8; x++) {
				row <<= 1;
				if (tmp[y][x] & b) {
					row |= 1;
				}
			}
			fwrite(&row, 1, 1, out_fptr);
		}
	}

//	printf("--\n");
}

int main(int argc, char **argv) {
	int i;
	FILE *fptr;

	if (argc < 2) {
		printf("Usage: ./genvga16 output_file\n");
		return -1;
	}

	fptr = fopen(argv[1], "wb");
	if (!fptr) {
		perror("fopen");
		return -1;
	}

	printf("Generating VGA16 font...\n");
	for (i=32; i<128; i++) {
	    render(font8x8_basic[i], i, fptr);
	}
	for (i=128; i<256; i++) {
	    render(font8x8_ext_latin[i-128], i, fptr);
	}

	fclose(fptr);

    return 0;
}
