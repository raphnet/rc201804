#include <stdio.h>


int main(int argc, char **argv)
{
	int y;
	FILE *fptr;
	unsigned char buf[2];

	if (argc < 2) {
		fprintf(stderr, "Usage: ./cgarows output.bin\n");
		return 1;
	}

	fptr = fopen(argv[1], "wb");
	if (!fptr) {
		perror("fopen");
		return 1;
	}

	printf("Generating CGA row pointers... (output in '%s'\n", argv[1]);
	for (y=0; y<200; y++) {
		unsigned short addr;

		addr = y/2 * 80;
		addr += (y&1) * 0x2000;
		//printf("y=%-3d : 0x%04x \n", y, addr);

		// Little endian
		buf[0] = addr & 0xff;
		buf[1] = addr >> 8;
		if (1 != fwrite(buf, 2, 1, fptr)) {
			perror("fwrite");
			fclose(fptr);
			return 1;
		}
	}

	fclose(fptr);
	return 0;
}
