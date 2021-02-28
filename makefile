all: exec

exec: ass3.s
	nasm -g -F dwarf -f elf32 ass3.s -o ass3.o
	nasm -g -F dwarf -f elf32 printer.s -o printer.o
	nasm -g -F dwarf -f elf32 drone.s -o drone.o
	nasm -g -F dwarf -f elf32 target.s -o target.o
	nasm -g -F dwarf -f elf32 scheduler.s -o scheduler.o
	gcc -m32 -gdwarf ass3.o printer.o drone.o target.o scheduler.o -o ass3
	rm ass3.o printer.o drone.o target.o scheduler.o
.PHONY: clean
clean:
	rm -rf ./*.o main
