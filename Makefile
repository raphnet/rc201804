NASM=nasm
GRAPHICS_CGA=$(wildcard cga_graphics/*.png)
GRAPHICS_TGA=$(wildcard tga_graphics/*.png)
GRAPHICS_VGA16=$(wildcard vga16_graphics/*.png)

GFX_CGA=$(patsubst cga_graphics/%.png,res_cga/%.cga,$(GRAPHICS_CGA)) res_cga/title.lz4
GFX_TGA=$(patsubst tga_graphics/%.png,res_tga/%.tga,$(GRAPHICS_TGA)) res_tga/title.lz4
GFX_VGA16=$(patsubst vga16_graphics/%.png,res_vga16/%.vga16,$(GRAPHICS_VGA16)) res_vga16/title.lz4

cgalib=cgalib.asm cgalib_blit8x8.asm cgalib_blit16x16.asm res_cga/rows.bin cgalib_effects.asm res_cga/font.bin videolib_common.asm
tgalib=tgalib.asm res_tga/rows.bin res_tga/font.bin tgalib_effects.asm videolib_common.asm
vga16lib=vgalib.asm vgalib_effects.asm videolib_common.asm res_vga16/font.bin vgaregs.asm
MOUSE=mouse.asm mousepointer.bin

# The first dependency must be rain.asm. Other files are there to trigger recompile when modified. (they are all included by rain.asm)
RAIN_DEPS=rain.asm zapper.asm gameloop.asm mobj.asm score.asm random.asm sinlut.bin messagescreen.asm lang.asm $(MOUSE)

all: zapdemo1.com zapdemo2.com vgazap1.com rain.com rainvga.com raincga.com


### Executables

zapdemo1.com: zapdemo1.asm zapper.asm gameloop.asm zapdemo1.asm random.asm $(tgalib) $(GFX_TGA) sinlut.bin
	$(NASM) $< -fbin -o $@ -l $@.lst $(MOUSE_SUPPORT)
	ls -l $@

zapdemo2.com: zapdemo2.asm zapper.asm random.asm $(tgalib) $(GFX_TGA) sinlut.bin
	$(NASM) $< -fbin -o $@ -l $@.lst $(MOUSE_SUPPORT)
	ls -l $@

vgazap1.com: vgazap1.asm zapper.asm $(vga16lib) $(GFX_VGA16) $(MOUSE)
	$(NASM) $< -fbin -o $@ -l $@.lst
	ls -l $@

# RainZapper : Tandy Version
rain.com: $(RAIN_DEPS) $(tgalib) $(GFX_TGA)
	$(NASM) $< -fbin -o $@ -l $@.lst -DMOUSE_SUPPORT
	ls -l $@

# RainZapper : VGA Version
rainvga.com: $(RAIN_DEPS) $(vga16lib) $(GFX_VGA16)
	$(NASM) $< -fbin -o $@ -l $@.lst -DVGA_VERSION -DMOUSE_SUPPORT
	ls -l $@

# RainZapper : CGA Version
raincga.com: $(RAIN_DEPS) $(cgalib) $(GFX_CGA)
	$(NASM) $< -fbin -o $@ -l $@.lst -DCGA_VERSION -DMOUSE_SUPPORT
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

runrainvga: rainvga.com
	dosbox -noautoexec -conf vga.dosbox.conf $<

runraincga: raincga.com
	dosbox -noautoexec -conf cga.dosbox.conf $<

release:

clean:
	rm -f zapdemo1.com $(GFX_CGA) $(GFX_TGA) res_cga/* res_tga/* res_vga16/*
	$(MAKE) -C png2cga clean
	$(MAKE) -C png2tga clean
	$(MAKE) -C png2vga16 clean
	$(MAKE) -C png2mp clean
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

png2cga/%:
	$(MAKE) -C png2cga

png2vga16/%:
	$(MAKE) -C png2vga16

png2mp/%:
	$(MAKE) -C png2mp

scr/%:
	$(MAKE) -C scr

### Resource conversion

res_cga/%.cga: cga_graphics/%.png png2cga/png2cga
	./png2cga/png2cga $< $@

res_tga/%.tga: tga_graphics/%.png png2tga/png2tga
	./png2tga/png2tga $< $@

res_vga16/%.vga16: vga16_graphics/%.png png2vga16/png2vga16
	./png2vga16/png2vga16 $< $@

mousepointer.bin: mousepointer.png png2mp/png2mp
	./png2mp/png2mp $< $@

res_cga/%.lz4: res_cga/%.cga scr/scr2lz4
	./scr/scr2lz4 $< $@

res_tga/%.lz4: res_tga/%.tga scr/scr2lz4
	./scr/scr2lz4 $< $@

res_vga16/%.lz4: res_vga16/%.vga16 scr/scr2lz4_vga16
	./scr/scr2lz4_vga16 $< $@

### Generated files (included from sources)

# Look-up table used by sin.asm
sinlut.bin: generators/gensinlut
	./generators/gensinlut $@

res_cga/font.bin: font8x8/gencga
	./font8x8/gencga $@

res_vga16/font.bin: font8x8/genvga16
	./font8x8/genvga16 $@

res_tga/font.bin: font8x8/gentga
	./font8x8/gentga $@

res_tga/rows.bin: generators/tgarows
	./generators/tgarows $@

res_cga/rows.bin: generators/cgarows
	./generators/cgarows $@


