#include <stdio.h>
#include <math.h>


int main(int argc, char **argv)
{
	int angle_degrees;
	FILE *outfile;

	if (argc != 2) {
		printf("Usage: ./gensinlut output_file.bin\n");
		printf("\n");
		printf("This tool generates a lookup table for angles from 0 to 90 in increments of 1.\n");
		printf("Each SIN value is multiplied by 1000 and stored as a little endian 16 bit integer.\n");
		return 1;
	}

	outfile = fopen(argv[1], "wb");
	if (!outfile) {
		perror("fopen");
		return -1;
	}

	printf("Generating sinus look-up table...\n");
	for (angle_degrees=0; angle_degrees<90; angle_degrees++) {
		double rad, s;
		unsigned short outval;
		unsigned char bytes[2];

		rad = (double)angle_degrees * M_PI*2 / 360.0;
		s = sin(rad);
		outval = 1000 * s;
		bytes[0] = outval & 0xff;
		bytes[1] = (outval >> 8) & 0xff;
		fwrite(bytes, 2, 1, outfile);

		printf("%d -> %.02lf, ", angle_degrees, s);
	}
	printf("\n");

	fclose(outfile);

	return 0;
}
