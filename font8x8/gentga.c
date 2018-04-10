#include <stdio.h>
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

	for (n=0; n<4; n++) {
		for (y=n; y < 8; y+=4) {
			unsigned char line[4] = { 0,0,0,0 };

			line[0] = tmp[y][0] << 4;
			line[0] |= tmp[y][1];
			line[1] = tmp[y][2] << 4;
			line[1] |= tmp[y][3];
			line[2] = tmp[y][4] << 4;
			line[2] |= tmp[y][5];
			line[3] = tmp[y][6] << 4;
			line[3] |= tmp[y][7];
			fwrite(line, 4, 1, out_fptr);
		}
    }

//	printf("--\n");
}

int main(int argc, char **argv) {
	int i;
	FILE *fptr;

	if (argc < 2) {
		printf("Usage: ./gentga output_file\n");
		return -1;
	}

	fptr = fopen(argv[1], "wb");
	if (!fptr) {
		perror("fopen");
		return -1;
	}

	printf("Generating TGA font...\n");
	for (i=32; i<128; i++) {
	    render(font8x8_basic[i], i, fptr);
	}
	for (i=128; i<256; i++) {
	    render(font8x8_ext_latin[i-128], i, fptr);
	}

	fclose(fptr);

    return 0;
}
