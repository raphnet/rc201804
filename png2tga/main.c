#include <stdio.h>
#include <string.h>
#include <stdint.h>

#include <png.h>

int convertPNG(FILE *fptr_in, FILE *fptr_out, int cga_compat);

static void printusage(void)
{
	printf("Usage: ./png2tga input_file output_file\n");
	printf("\n");
	printf("input_file must be a 4-bit color PNG file.\n");
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
		case 2:
			for (y=0; y<h; y++) {
				unsigned char row[w/2];
				int addr;

				memset(row, 0, sizeof(row));

				for (x=0; x<w; x++) {
					unsigned char b;


					b = row_pointers[y][x/4];
					b >>= ((x&3)^0x3)*2;
					b &= 3;

					switch(b & 0x03)
					{
						case 0: b = 0; break;
						case 1: b = 2; break;
						case 2: b = 4; break;
						case 3: b = 6; break;
					}

					row[x/2] |= (b<<4)>>((x&1)*4);
				}

				addr = (y/4)*(w/2) + (y&3)*(w/2*h/4);

				fseek(fptr_out, addr, SEEK_SET);
				fwrite(row, w/2, 1, fptr_out);
			}
			break;

		case 4:
			for (y=0; y<h; y++) {
				unsigned char row[w/2];
				int addr;

				memset(row, 0, sizeof(row));

				for (x=0; x<w; x++) {
					unsigned char b;


					b = row_pointers[y][x/2];
					b >>= ((x&1)^0x1)*4;
					b &= 0xf;


					row[x/2] |= (b<<4)>>((x&1)*4);
				}

				addr = (y/4)*(w/2) + (y&3)*(w/2*h/4);

				fseek(fptr_out, addr, SEEK_SET);
				fwrite(row, w/2, 1, fptr_out);
			}
			break;


		case 8:
			for (y=0; y<h; y++) {
				unsigned char row[w/2];
				int addr;

				memset(row, 0, sizeof(row));

				for (x=0; x<w; x++) {
					unsigned char b;

					b = row_pointers[y][x];
					b &= 0xf;

					switch(b & 0x0f)
					{
						case 0: b = 0; break;
						case 1: b = 2; break;
						case 2: b = 4; break;
						case 3: b = 6; break;
					}
					row[x/2] |= (b<<4)>>((x&1)*4);
				}

				addr = (y>>2)*(w>>1) + ((y&3) * (w*h/8));
				if (h == 52) {
					printf("%d: %d : %d\n", y, addr, w/2);
				}

				fseek(fptr_out, addr, SEEK_SET);
				fwrite(row, w/2, 1, fptr_out);
			}

			break;

		default:
			fprintf(stderr, "Unimplemented color depth\n");
			return -1;

	}

done:
	png_destroy_read_struct(&png_ptr, &info_ptr, NULL);

	return ret;
}
