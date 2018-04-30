#include <stdio.h>
#include <stdint.h>

#include <png.h>

int convertPNG(FILE *fptr_in, FILE *fptr_out, int cga_compat);

static void printusage(void)
{
	printf("Usage: ./png2mp input_file output_file\n");
	printf("\n");
	printf("This tool converts a PNG file to the binary format suitable for int 33h mouse drivers\n");
	printf("input_file must be a 16x32 1-bit color PNG file.\n");
	printf("The top 16x16 part is the AND mask, the bottom 16x16 part is the XOR mask.\n");
}

int main(int argc, char **argv)
{
	FILE *fptr_in = NULL, *fptr_out = NULL;
	uint8_t header[8];
	int ret = 0;
	int cga_compat = 1;

	if (argc < 3) {
		printusage();
		return 1;
	}

	fptr_in = fopen(argv[1], "rb");
	if (!fptr_in) {
		perror("fopen");
		return 2;
	}

	if (8 != fread(header, 1, 8, fptr_in)) {
		perror("fread");
		ret = 3;
		goto done;
	}

	if (png_sig_cmp(header, 0, 8)) {
		fprintf(stderr, "Not a PNG file\n");
		ret = 3;
		goto done;
	}

	fptr_out = fopen(argv[2], "wb");
	if (!fptr_out) {
		perror("fopen outfile");
		ret = 4;
		goto done;
	}

	if (argc > 3)
		cga_compat = 0;

	ret = convertPNG(fptr_in, fptr_out, cga_compat);

done:
	if (fptr_out) {
		fclose(fptr_out);
	}

	if (fptr_in) {
		fclose(fptr_in);
	}

	return ret;
}

int convertPNG(FILE *fptr_in, FILE *fptr_out, int cga_compat)
{
	png_structp png_ptr;
	png_infop info_ptr;
	png_bytep *row_pointers;
	int w,h,depth,color;
	int ret;
	int x,y;

	png_ptr = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
	if (!png_ptr)
		return -1;

	info_ptr = png_create_info_struct(png_ptr);
	if (!info_ptr) {
		png_destroy_read_struct(&png_ptr, NULL, NULL);
		return -1;
	}

	if (setjmp(png_jmpbuf(png_ptr))) {
		ret = -1;
		goto done;
	}

	png_init_io(png_ptr, fptr_in);
	png_set_sig_bytes(png_ptr, 8);

	//png_read_png(png_ptr, info_ptr, PNG_TRANSFORM_STRIP_ALPHA | PNG_TRANSFORM_PACKING, NULL);
	png_read_png(png_ptr, info_ptr, PNG_TRANSFORM_STRIP_ALPHA, NULL);

	w = png_get_image_width(png_ptr, info_ptr);
	h = png_get_image_height(png_ptr, info_ptr);
	depth = png_get_bit_depth(png_ptr, info_ptr);
	color = png_get_color_type(png_ptr, info_ptr);

	printf("Image: %d x %d, ",w,h);
	printf("Bit depth: %d, ", depth);
	printf("Color type: %d\n", color);
	row_pointers = png_get_rows(png_ptr, info_ptr);

	if (w != 16) {
		fprintf(stderr, "Width must be 16\n");
		return -1;
	}

	switch(color)
	{
		case PNG_COLOR_TYPE_PALETTE:
			//printf("Processing paletized image\n");
			if (depth != 4) {
				if (depth == 8) {
					for (y=0; y<h; y++) {
						for (x=0; x<w; x++) {
							if (row_pointers[y][x]>3) {
								fprintf(stderr, "Palette has too many colors.\n");
							}
						}
					}
					// Only indexes 0-3 are used, we can go on
					break;
				} // depth = 8

				if (depth < 4)
					break;

				fprintf(stderr, "Palette has too many colors.\n");
				ret = -1;
				goto done;
			}
			break;
		default:
			fprintf(stderr, "Unsupported color type. File must use a 2bit palette.\n");
			ret = -1;
			goto done;
	}

	switch(depth)
	{
		case 1:
			for (y=0; y<h; y++) {
				unsigned char w[2];

				w[0] = row_pointers[y][1];
				w[1] = row_pointers[y][0];

				fwrite(w, 2, 1, fptr_out);

			}
			ret = 0;
			break;

		default:
			fprintf(stderr, "Unimplemented color depth\n");
			return -1;

	}

done:
	png_destroy_read_struct(&png_ptr, &info_ptr, NULL);

	return ret;
}
