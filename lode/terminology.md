# Terminology

## CPU Architecture

- **8080** - Intel's 8-bit microprocessor (1974), basis for CP/M systems
- **Z80** - Zilog's 8080-compatible CPU with extended instruction set
- **Register** - CPU storage location (A, B, C, D, E, H, L, SP, PC)
- **Register pair** - Two 8-bit registers used as 16-bit (BC, DE, HL, SP)
- **PSW** - Program Status Word (A register + flags)
- **Flags** - S (sign), Z (zero), AC (aux carry), P (parity), CY (carry)

## Instruction Types

- **Mnemonic** - Symbolic instruction name (MOV, ADD, JMP)
- **Opcode** - Binary encoding of instruction (1-3 bytes)
- **Operand** - Instruction argument (register, immediate, address)
- **Immediate** - Literal value embedded in instruction
- **Direct** - Memory address in instruction
- **Indirect** - Address in register pair (e.g., M means [HL])

## Intel 8080 Mnemonics

- **MOV** - Move register to register
- **MVI** - Move immediate to register
- **LXI** - Load register pair immediate (16-bit)
- **LDA/STA** - Load/store accumulator direct
- **LHLD/SHLD** - Load/store HL direct
- **LDAX/STAX** - Load/store A via BC or DE
- **XCHG** - Exchange DE and HL
- **PUSH/POP** - Stack operations
- **ADD/ADI** - Add (register/immediate)
- **SUB/SUI** - Subtract
- **INR/DCR** - Increment/decrement register
- **INX/DCX** - Increment/decrement register pair
- **CMP/CPI** - Compare
- **ANA/ANI** - AND
- **ORA/ORI** - OR
- **XRA/XRI** - XOR
- **RLC/RRC/RAL/RAR** - Rotate accumulator
- **JMP/Jcc** - Jump (conditional: JZ, JNZ, JC, JNC, JP, JM, JPE, JPO)
- **CALL/Ccc** - Call subroutine (conditional variants)
- **RET/Rcc** - Return (conditional variants)
- **RST n** - Restart (call to 8*n)
- **IN/OUT** - Port I/O
- **EI/DI** - Enable/disable interrupts
- **HLT** - Halt CPU
- **NOP** - No operation

## Assembler Directives

- **ORG** - Set assembly origin address
- **EQU** - Define constant symbol
- **SET/DEFL** - Define reassignable symbol
- **DB/DEFB** - Define byte(s)
- **DW/DEFW** - Define word(s) (16-bit)
- **DS/DEFS** - Define storage (reserve bytes)
- **END** - End of source, optional entry point
- **IF/ELSE/ENDIF** - Conditional assembly
- **MACRO/ENDM** - Macro definition
- **INCLUDE** - Include source file

## Macro Terms

- **Formal parameter** - Placeholder in macro definition
- **Actual parameter** - Value passed during macro invocation
- **Local symbol** - Symbol unique to each macro expansion
- **REPT** - Repeat block n times
- **IRP** - Indefinite repeat (iterate over list)
- **IRPC** - Indefinite repeat over characters

## CP/M Terms

- **TPA** - Transient Program Area (0100H to BDOS)
- **BDOS** - Basic Disk Operating System (system calls)
- **CCP** - Console Command Processor
- **BIOS** - Basic I/O System
- **FCB** - File Control Block (36 bytes)
- **DMA** - Data Memory Address (default 0080H)
- **COM file** - CP/M executable (loads at 0100H)

## Source Formats

- **.8hx** - Extended hex format: raw hex bytes with comments, labels, directives
- **Stage 0 format** - Pure hex bytes, comments only (no labels)
- **Stage 1 format** - Hex bytes with labels (`LABEL:`), ORG, END, symbol references
- **Stage 2 format** - Hex opcodes with DB, DW, DS, EQU, expressions (planned)
- **Stage 3 format** - Full mnemonic assembler syntax (JMP, CALL, MOV, etc.)

## Output Formats

- **Intel HEX** - ASCII hex records with checksums
- **CMD** - TRS-80 DOS executable format
- **CIM** - Core-in-memory raw binary
- **REL** - Relocatable object module
- **COM** - CP/M executable (raw binary, loads at 0100H)

## Assembly Process

- **Pass 1** - Collect symbol definitions, calculate addresses
- **Pass 2** - Generate code, resolve forward references
- **Symbol table** - Map of names to values/addresses
- **Location counter** - Current assembly address
- **Forward reference** - Symbol used before defined
