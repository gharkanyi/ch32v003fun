ifeq ($(OS),Windows_NT)
    PREFIX?=riscv64-unknown-elf
else
    ifeq (, $(shell which riscv64-unknown-elf-gcc))
        PREFIX?=riscv64-elf
    else
        PREFIX?=riscv64-unknown-elf
    endif
endif

TARGET_MCU?=CH32V003
TARGET_EXT?=c

CH32V003FUN?=../../ch32v003fun
MINICHLINK?=$(CH32V003FUN)/../minichlink

CFLAGS+= \
	-g -Os -flto -fdata-sections -ffunction-sections \
	-static-libgcc \
	-march=rv32ec \
	-mabi=ilp32e \
	-I/usr/include/newlib \
	-I$(CH32V003FUN)/../extralibs \
	-I$(CH32V003FUN) \
	-nostdlib \
	-I. -Wall $(EXTRA_CFLAGS)

WRITE_SECTION?=flash
SYSTEM_C?=$(CH32V003FUN)/ch32v003fun.c

ifeq ($(TARGET_MCU),CH32V003)
	CFLAGS+= \
		-g -Os -flto -ffunction-sections \
		-static-libgcc \
		-march=rv32ec \
		-mabi=ilp32e \
		-I/usr/include/newlib \
		-I$(CH32V003FUN)/../extralibs \
		-I$(CH32V003FUN) \
		-nostdlib \
		-DCH32V003=1 \
		-I. -Wall $(EXTRA_CFLAGS)

	GENERATED_LD_FILE?=$(CH32V003FUN)/generated_ch32v003.ld
	LINKER_SCRIPT?=$(GENERATED_LD_FILE)
else
	ifeq ($(findstring CH32V10,$(TARGET_MCU)),CH32V10)
		include $(CH32V003FUN)/ch32v10xfun.mk
	else ifeq ($(findstring CH32V20,$(TARGET_MCU)),CH32V20)
		include $(CH32V003FUN)/ch32v20xfun.mk
	else ifeq ($(findstring CH32V30,$(TARGET_MCU)),CH32V30)
		include $(CH32V003FUN)/ch32v30xfun.mk
	else
		$(error Unknown MCU $(TARGET_MCU))
	endif
endif

LDFLAGS+=-T $(LINKER_SCRIPT) -Wl,--gc-sections -L$(CH32V003FUN)/../misc -lgcc

ifeq ($(TARGET_MCU), CH32V003)

$(TARGET).elf : $(SYSTEM_C) $(TARGET).$(TARGET_EXT) $(ADDITIONAL_C_FILES)
	$(PREFIX)-gcc -o $@ $^ $(CFLAGS) $(LDFLAGS)

endif

$(TARGET).bin : $(TARGET).elf
	$(PREFIX)-size $^
	$(PREFIX)-objdump -S $^ > $(TARGET).lst
	$(PREFIX)-objdump -t $^ > $(TARGET).map
	$(PREFIX)-objcopy -O binary $< $(TARGET).bin
	$(PREFIX)-objcopy -O ihex $< $(TARGET).hex

ifeq ($(OS),Windows_NT)
closechlink :
	-taskkill /F /IM minichlink.exe /T
else
closechlink :
	-killall minichlink
endif

terminal : monitor

monitor :
	$(MINICHLINK)/minichlink -T

gdbserver : 
	-$(MINICHLINK)/minichlink -baG

clangd :
	make clean
	bear -- make build
	@echo "CompileFlags:" > .clangd
	@echo "  Remove: [-march=*, -mabi=*]" >> .clangd

clangd_clean :
	rm -f compile_commands.json .clangd
	rm -rf .cache

FLASH_COMMAND?=$(MINICHLINK)/minichlink -w $< $(WRITE_SECTION) -b

$(GENERATED_LD_FILE) :
	$(PREFIX)-gcc -E -P -x c -DTARGET_MCU=CH32V003 $(CH32V003FUN)/ch32v003fun.ld > $(GENERATED_LD_FILE)


cv_flash : $(TARGET).bin
	make -C $(MINICHLINK) all
	$(FLASH_COMMAND)

cv_clean :
	rm -rf $(TARGET).elf $(TARGET).bin $(TARGET).hex $(TARGET).lst $(TARGET).map $(TARGET).hex || true

build : $(TARGET).bin
