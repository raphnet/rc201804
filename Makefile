NASM=nasm
GRAPHICS_CGA=$(wildcard cga_graphics/*.png)
GRAPHICS_TGA=$(wildcard tga_graphics/*.png)

GFX_CGA=$(patsubst cga_graphics/%.png,res/%.cga,$(GRAPHICS_CGA))
GFX_TGA=$(patsubst tga_graphics/%.png,restga/%.tga,$(GRAPHICS_TGA))

cgalib=cgalib.asm cgalib_blit8x8.asm cgalib_blit16x16.asm res/cgarows.bin cgalib_effects.asm res/cgafont.bin videolib_common.asm
tgalib=tgalib.asm res/tgarows.bin res/tgafont.bin tgalib_effects.asm videolib_common.asm

all: zapdemo1.com zapdemo2.com


### Executables

zapdemo1.com: zapdemo1.asm zapper.asm random.asm $(tgalib) $(GFX_TGA) sinlut.bin
	$(NASM) $< -fbin -o $@ -l $@.lst -DMOUSE_SUPPORT
	ls -l $@

zapdemo2.com: zapdemo2.asm zapper.asm random.asm $(tgalib) $(GFX_TGA) sinlut.bin
	$(NASM) $< -fbin -o $@ -l $@.lst
	ls -l $@

### Test, deployment and housekeeping

run: zapdemo1.com
	dosbox -noautoexec -conf tga.dosbox.conf $<

run2: zapdemo2.com
	dosbox -noautoexec -conf tga.dosbox.conf $<

release:

clean:
	rm -f zapdemo1.com $(GFX_CGA) $(GFX_TGA) rescga/* restga/*
	$(MAKE) -C generators clean
	$(MAKE) -C font8x8 clean

### Generators for code or tables included by source code

generators/%:
	$(MAKE) -C generators

font8x8/%:
	$(MAKE) -C font8x8

### Generated files (included from sources)

# Look-up table used by sin.asm
sinlut.bin: generators/gensinlut
	./generators/gensinlut $@

res/cgafont.bin: font8x8/gencga
	./font8x8/gencga $@

res/tgafont.bin: font8x8/gentga
	./font8x8/gentga $@

res/tgarows.bin: generators/tgarows
	./generators/tgarows $@

res/cgarows.bin: generators/cgarows
	./generators/cgarows $@


