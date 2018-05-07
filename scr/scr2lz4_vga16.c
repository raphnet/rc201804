#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <lz4.h>
#include <lz4hc.h>
#include <getopt.h>

int main(int argc, char **argv)
{
	FILE *fptr_in, *fptr_out;
	size_t input_size;
	uint8_t *inputbuf, *outputbuf;
	int max_outputsize;
	int compressed_size;
	int stride;
	int plane_size;
	int num_planes;
	int yres;
	uint8_t tmpbuf[16];
	size_t expanded_input_size;
	int i, y;

	if (argc < 2) {
		printf("Usage: ./scr2lz4_vga16 input.vga16 output.lz4\n");
		return 1;
	}

	fptr_in = fopen(argv[1], "rb");
	if (!fptr_in) {
		perror("fopen");
		return -1;
	}

	fptr_out = fopen(argv[2], "wb");
	if (!fptr_in) {
		perror("fopen");
		return -1;
	}

	fseek(fptr_in, 0, SEEK_END);
	input_size = ftell(fptr_in);
	fseek(fptr_in, 0, SEEK_SET);

	printf("Input file size: 0x%04zx\n", input_size);

	switch(input_size)
	{
		case 640*480/2:
			stride = 640 / 8;
			plane_size = 640*480/8;
			num_planes = 4;
			yres = 480;
			printf("VGA16 640x480 mode\n");
			break;
		default:
			fprintf(stderr, "Not supported\n");
			return 1;
	}

	expanded_input_size = input_size;

	printf("Plane size: 0x%04x\n", plane_size);
	printf("Num planes: %d\n", num_planes);
	printf("Stride size: %d\n", stride);
	printf("Height: %d\n", yres);

	if (input_size > expanded_input_size) {
		fprintf(stderr, "Input file larger than expected\n");
		return 1;
	}

	inputbuf = calloc(1, expanded_input_size);
	if (!inputbuf) {
		perror("inputbuf");
		return 1;
	}

	max_outputsize = LZ4_compressBound(plane_size);
	printf("Worst case output buffer size: 0x%04x\n", max_outputsize);

	outputbuf = calloc(1, max_outputsize);
	if (!outputbuf) {
		perror("outputbuf");
		return 1;
	}

	for (y=0; y<yres; y++) {
		int res;
		for (i=0; i<4; i++) {
			//printf("Line %d, plane %d, strd: %d\n", y, i, stride);
			// Read one scanline in one color
			res = fread(inputbuf + i*plane_size + y * stride, stride, 1, fptr_in);
			if (res != 1) {
				perror("read error");
				return 1;
			}
		}
	}

	for (i=0; i<num_planes; i++)
	{
		printf("- Plane %d of %d\n", i+1, num_planes);
		//compressed_size = LZ4_compressHC2((char*)inputbuf, (char*)outputbuf, expanded_input_size, 9);
		compressed_size = LZ4_compressHC2((char*)inputbuf + plane_size * i, (char*)outputbuf, plane_size, 9);

		printf("Compressed size: %d (%d%% of original %d bytes file)\n",
			compressed_size, compressed_size * 100 / (int)plane_size, plane_size);

		// magic number
		tmpbuf[0] = 0x02;
		tmpbuf[1] = 0x21;
		tmpbuf[2] = 0x4C;
		tmpbuf[3] = 0x18;
		tmpbuf[4] = compressed_size;
		tmpbuf[5] = compressed_size >> 8;
		tmpbuf[6] = compressed_size >> 16;
		tmpbuf[7] = compressed_size >> 24;

		fwrite(tmpbuf, 8, 1, fptr_out);
		fwrite(outputbuf, compressed_size, 1, fptr_out);
		tmpbuf[0] = 0;
		//fwrite(tmpbuf, 1, 1, fptr_out);
	}

	fclose(fptr_in);
	fclose(fptr_out);

	return 0;
}
