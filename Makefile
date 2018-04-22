NASM=nasm
GRAPHICS_CGA=$(wildcard cga_graphics/*.png)
GRAPHICS_TGA=$(wildcard tga_graphics/*.png)

GFX_CGA=$(patsubst cga_graphics/%.png,res_cga/%.cga,$(GRAPHICS_CGA))
GFX_TGA=$(patsubst tga_graphics/%.png,res_tga/%.tga,$(GRAPHICS_TGA))

cgalib=cgalib.asm cgalib_blit8x8.asm cgalib_blit16x16.asm res_cga/rows.bin cgalib_effects.asm res_cga/font.bin videolib_common.asm
tgalib=tgalib.asm res_tga/rows.bin res_tga/font.bin tgalib_effects.asm videolib_common.asm

all: zapdemo1.com zapdemo2.com vgazap1.com rain.com


MOUSE_SUPPORT=
MOUSE_SUPPORT=-DMOUSE_SUPPORT

### Executables

zapdemo1.com: zapdemo1.asm zapper.asm gameloop.asm zapdemo1.asm random.asm $(tgalib) $(GFX_TGA) sinlut.bin
	$(NASM) $< -fbin -o $@ -l $@.lst $(MOUSE_SUPPORT)
	ls -l $@

zapdemo2.com: zapdemo2.asm zapper.asm random.asm $(tgalib) $(GFX_TGA) sinlut.bin
	$(NASM) $< -fbin -o $@ -l $@.lst $(MOUSE_SUPPORT)
	ls -l $@

vgazap1.com: vgazap1.asm vgalib.asm
	$(NASM) $< -fbin -o $@ -l $@.lst
	ls -l $@

rain.com: rain.asm zapper.asm gameloop.asm mobj.asm random.asm $(tgalib) $(GFX_TGA) sinlut.bin
	$(NASM) $< -fbin -o $@ -l $@.lst $(MOUSE_SUPPORT)
	ls -l $@


### Test, deployment and housekeeping

run: zapdemo1.com
	dosbox -noautoexec -conf tga.dosbox.conf $<

run2: zapdemo2.com
	dosbox -noautoexec -conf tga.dosbox.conf $<

runv1: vgazap1.com vgalib.asm
	dosbox -noautoexec -conf vga.dosbox.conf $<

runrain: rain.com
	dosbox -noautoexec -conf tga.dosbox.conf $<

release:

clean:
	rm -f zapdemo1.com $(GFX_CGA) $(GFX_TGA) rescga/* restga/*
	$(MAKE) -C generators clean
	$(MAKE) -C font8x8 clean
	$(MAKE) -C scr clean

### Generators for code or tables included by source code

generators/%:
	$(MAKE) -C generators

font8x8/%:
	$(MAKE) -C font8x8

scr/%:
	$(MAKE) -C scr

png2tga/%:
	$(MAKE) -C png2tga

### Resource conversion

res_tga/%.tga: tga_graphics/%.png png2tga/png2tga
	./png2tga/png2tga $< $@

### Generated files (included from sources)

# Look-up table used by sin.asm
sinlut.bin: generators/gensinlut
	./generators/gensinlut $@

res_cga/cgafont.bin: font8x8/gencga
	./font8x8/gencga $@

res_tga/font.bin: font8x8/gentga
	./font8x8/gentga $@

res_tga/rows.bin: generators/tgarows
	./generators/tgarows $@

res_cga/rows.bin: generators/cgarows
	./generators/cgarows $@


