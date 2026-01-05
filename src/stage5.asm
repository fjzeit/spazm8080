; STAGE5.ASM - Stage 4 rewritten in mnemonics
; Assembled by STAGE4.COM
;
; Adds:
;   - 8080 mnemonic parsing (MOV, MVI, JMP, CALL, etc.)
;   - Register and register pair operand handling
;   - Retains hex byte fallback via HEXLN
;
; Memory Layout (code first, buffers high):
;   0100-0FFF: Code (~3.8KB room for mnemonic parser)
;   1000-107F: TOKBUF (128 bytes)
;   1080-10CF: LINBUF (80 bytes)
;   10D0-10DF: Variables (16 bytes)
;   1100-117F: IBUF (128 bytes)
;   1180-11FF: OBUF (128 bytes)
;   1200-123F: OFCB (64 bytes)
;   2000+:     Symbol table (256 entries x 8 bytes)
;
; Variables at 10D0:
;   10D0: PASS    (1 byte)  - 0=pass1, 1=pass2
;   10D1: ICNT    (1 byte)  - Input buffer count
;   10D2: IPTR    (2 bytes) - Input buffer pointer
;   10D4: OCNT    (1 byte)  - Output buffer count
;   10D5: OPTR    (2 bytes) - Output buffer pointer
;   10D7: SYMCNT  (1 byte)  - Symbol count
;   10D8: LOCTR   (2 bytes) - Location counter
;   10DA: LNPTR   (2 bytes) - Line pointer

        ORG 0100H

; ============================================================
; EQU definitions for memory locations
; ============================================================
BOOT    EQU 0000H
BDOS    EQU 0005H
TAB     EQU 09H
LZ1     EQU 7BH         ; 'z'+1 for range check
L91     EQU 3AH         ; '9'+1 for range check
LZU1    EQU 5BH         ; 'Z'+1 for range check
FCB     EQU 005CH
FCBEX   EQU 0068H       ; FCB+12 (extent)
FCBCR   EQU 007CH       ; FCB+32 (current record)
TOKBUF  EQU 1000H
LINBUF  EQU 1080H
PASS    EQU 10D0H
ICNT    EQU 10D1H
IPTR    EQU 10D2H
OCNT    EQU 10D4H
OPTR    EQU 10D5H
SYMCNT  EQU 10D7H
LOCTR   EQU 10D8H
LNPTR   EQU 10DAH
IBUF    EQU 1100H
OBUF    EQU 1180H
OFCB    EQU 1200H
SYMTAB  EQU 2000H

; ============================================================
; START - Entry point
; ============================================================
START:
; Set FCB extension to .8HX
        LXI H,0065H     ; FCB+9
        MVI M,'8'
        INX H
        MVI M,'H'
        INX H
        MVI M,'X'

; Open input file
        LXI D,FCB
        MVI C,15        ; open
        CALL BDOS
        INR A
        JZ NOFILE

; Copy FCB to OFCB, set .COM extension
        LXI H,FCB
        LXI D,OFCB
        MVI B,9

CPFCB:
        MOV A,M
        STAX D
        INX H
        INX D
        DCR B
        JNZ CPFCB

; Set .COM extension
        MVI A,'C'
        STAX D
        INX D
        MVI A,'O'
        STAX D
        INX D
        MVI A,'M'
        STAX D
        INX D

; Zero rest of OFCB (24 bytes)
        MVI B,24
ZFCB:
        XRA A
        STAX D
        INX D
        DCR B
        JNZ ZFCB

; Delete old output, create new
        LXI D,OFCB
        MVI C,19        ; delete
        CALL BDOS
        LXI D,OFCB
        MVI C,22        ; make
        CALL BDOS
        INR A
        JZ DSKFUL

; ============================================================
; INIT - Initialize variables
; ============================================================
INIT:
        XRA A
        STA PASS
        STA ICNT
        STA OCNT
        STA SYMCNT

; Set LOCTR to 0100H
        LXI H,0100H
        SHLD LOCTR

; Init OPTR
        LXI H,OBUF
        SHLD OPTR

; ============================================================
; PASS1 - First pass loop
; ============================================================
PASS1:
        CALL RDLINE
        JC REWIND       ; EOF
        CALL PARSE
        JMP PASS1

; Rewind for pass 2
REWIND:
        LXI D,FCB
        MVI C,16        ; close
        CALL BDOS
        LXI D,FCB
        MVI C,15        ; open
        CALL BDOS

; P1END - Start pass 2
P1END:
        XRA A
        STA FCBCR       ; reset CR (FCB+32)
        STA FCBEX       ; reset extent (FCB+12)
; Re-open file to reload extent 0 allocation info
        LXI D,FCB
        MVI C,15        ; open file
        CALL BDOS
        XRA A           ; BDOS trashed A
        STA ICNT
        INR A
        STA PASS

; Reset LOCTR
        LXI H,0100H
        SHLD LOCTR

; ============================================================
; PASS2 - Second pass loop
; ============================================================
PASS2:
        CALL RDLINE
        JC DONE
        CALL PARSE
        JMP PASS2

; DONE
DONE:
        CALL FLUSH
        LXI D,OFCB
        MVI C,16        ; close
        CALL BDOS
        JMP BOOT

; ============================================================
; RDLINE - Read line into LINBUF
; Returns: CY=1 if EOF
; ============================================================
RDLINE:
        LXI H,LINBUF
        MVI B,126

RL1:
        CALL GETCHR
        JC RLEOF
        CPI 0AH         ; LF
        JZ RLEOL
        CPI 0DH         ; CR
        JZ RL1          ; skip CR
        MOV M,A
        INX H
        DCR B
        JNZ RL1

; RL_TRUNC - Skip to EOL
RLTRUN:
        CALL GETCHR
        JC RLEOF
        CPI 0AH
        JNZ RLTRUN

; RL_EOL
RLEOL:
        MVI M,0
        LXI H,LINBUF
        SHLD LNPTR
        ORA A           ; clear CY
        RET

; RL_EOF
RLEOF:
        STC
        RET

; ============================================================
; SKIPWS - Skip whitespace
; ============================================================
SKIPWS:
        LHLD LNPTR
SKW1:
        MOV A,M
        CPI ' '
        JZ SKW2         ; skip space
        CPI TAB
        JNZ SKW3        ; not whitespace, done
SKW2:
        INX H
        JMP SKW1
SKW3:
        SHLD LNPTR
        RET

; ============================================================
; PARSE - Parse current line
; ============================================================
PARSE:
        CALL SKIPWS
        LHLD LNPTR
        MOV A,M
        ORA A
        RZ              ; empty line
        CPI ';'
        RZ              ; comment

; Check for label (scan for colon)
        CALL CHKLBL
; Check for directive
        CALL CHKDIR
; Check for mnemonic (Stage 4)
        CALL CHKMNM
; Parse hex bytes (fallback)
        CALL HEXLN
        RET

; ============================================================
; CHKLBL - Check for and define label
; ============================================================
CHKLBL:
        LHLD LNPTR
        PUSH H          ; save start

; CL1 - Scan for colon
CL1:
        MOV A,M
        ORA A
        JZ CLNO         ; end of line
        CPI ':'
        JZ CLYES
        CPI ' '
        JZ CLNO
        CPI TAB
        JZ CLNO
        CPI ';'
        JZ CLNO
        INX H
        JMP CL1

; CL_NO - Not a colon-label, but check for EQU
CLNO:
        ; Stack: [label start]
        ; HL points to whitespace after potential label name
        SHLD LNPTR      ; save pos at whitespace
        CD SKIPWS       ; skip whitespace
        LHLD LNPTR
        CD CHEQU        ; check for "EQU"
        ORA A
        JNZ CLEQU
        ; Not EQU - restore original LNPTR
        POP H           ; label start
        SHLD LNPTR
        RET

; CL_EQU - Found EQU, parse value and define symbol
CLEQU:
        ; LNPTR is past "EQU"
        CD SKIPWS       ; skip whitespace after EQU
        CD EXPR         ; parse value -> HL
        XCHG            ; value to DE
        POP H           ; label start
        LDA PASS
        ORA A
        RNZ             ; pass 2, skip define
        CD DEFEQU       ; define symbol with value in DE
        RET

; CL_YES - Found label, define it
CLYES:
        POP H           ; start of label
        LDA PASS
        ORA A
        JNZ CLSKP       ; pass 2, skip define
        CALL DEFSYM
; Skip past colon
CLSKP:
        LHLD LNPTR

CL2:
        MOV A,M
        INX H
        CPI ':'
        JNZ CL2
        SHLD LNPTR
        RET

; ============================================================
; CHKDIR - Check for directive (ORG, END)
; O/o can only be ORG (no hex starts with O)
; E/e must check 2nd char: N/n = END, else hex (like E5)
; ============================================================
CHKDIR:
        CALL SKIPWS
        LHLD LNPTR
        MOV A,M
        ORA A
        RZ

; Check for 'O' (ORG) - no hex byte starts with O, so it's ORG
        CPI 'O'
        JZ CDORG
        CPI 'o'
        JZ CDORG
; Check for 'E' - could be END or hex like E5
        CPI 'E'
        JZ CKEND
        CPI 'e'
        JZ CKEND
; Check for 'D' (DB/DW/DS) - not a hex byte start
        CPI 'D'
        JZ CKDX
        CPI 'd'
        JZ CKDX
        RET

; CK_END - Check if E is followed by N (END) or digit (hex)
CKEND:
        INX H
        MOV A,M
        CPI 'N'
        JZ CDEND
        CPI 'n'
        JZ CDEND
; Not END, restore LNPTR
        LHLD LNPTR
        RET

; CD_ORG - Parse ORG directive
CDORG:
; Skip "ORG"
        INX H
        INX H
        INX H
        SHLD LNPTR
        CALL SKIPWS
        CALL EXPR
        SHLD LOCTR
        RET

; CD_END - END directive
CDEND:
; Set line to null AND update LNPTR so HEXLN sees empty
        LXI H,LINBUF
        MVI M,0
        SHLD LNPTR
        RET

; ============================================================
; CK_DX - Check for DEFB/DEFW/DEFS directives
; Uses DEFx names to avoid collision with hex byte DB (0xDB)
; ============================================================
CKDX:
        INX H           ; now at 2nd char
        MOV A,M
        ANI 0DFH        ; uppercase
        CPI 'E'
        JNZ CKDXN       ; not 'E', so not DEFx
        INX H           ; now at 3rd char
        MOV A,M
        ANI 0DFH
        CPI 'F'
        JNZ CKDXN
        INX H           ; now at 4th char
        MOV A,M
        ANI 0DFH
        CPI 'B'
        JZ GODEF
        CPI 'W'
        JZ GODEW
        CPI 'S'
        JZ GODES
CKDXN:
; Not a D-directive, restore LNPTR
        LHLD LNPTR
        RET

; ============================================================
; GO_DEFB - Parse DEFB directive
; Syntax: DEFB expr, expr, 'string'
; ============================================================
GODEF:
        INX H           ; skip 'B' of DEFB
        SHLD LNPTR

DBLP:
        CD SKIPWS       ; skip whitespace
        LHLD LNPTR
        MOV A,M
        ORA A
        JZ DBEND        ; end of line
        CPI ';'
        JZ DBEND        ; comment

; Check for quote (string)
        CPI '\''
        JZ DBSTR

; Otherwise parse expression as byte
        CD EXPR         ; get value -> HL
        MOV A,L
        CD OUTPUT       ; emit low byte only

; Check for comma
        CD SKIPWS       ; skip whitespace
        LHLD LNPTR
        MOV A,M
        CPI ','
        JNZ DBEND       ; done
        INX H           ; skip comma
        SHLD LNPTR
        JMP DBLP

; DB_STRING - Output characters between quotes
DBSTR:
        INX H           ; skip opening quote
        SHLD LNPTR

DBST1:
        LHLD LNPTR
        MOV A,M
        CPI '\''        ; closing quote
        JZ DBSTE
        ORA A
        JZ DBEND        ; unexpected end

; Output character
        CD OUTPUT       ; emit the character
        LHLD LNPTR
        INX H
        SHLD LNPTR
        JMP DBST1

DBSTE:
        INX H           ; skip closing quote
        SHLD LNPTR

; Check for comma after string
        CD SKIPWS       ; skip whitespace
        LHLD LNPTR
        MOV A,M
        CPI ','
        JNZ DBEND
        INX H           ; skip comma
        SHLD LNPTR
        JMP DBLP

; DB_END - Clear line so HEXLN doesn't process
DBEND:
        LXI H,LINBUF
        MVI M,0
        SHLD LNPTR
        RET

; ============================================================
; GO_DEFW - Parse DEFW directive
; Syntax: DEFW expr, expr (no strings)
; ============================================================
GODEW:
        INX H           ; skip 'W' of DEFW
        SHLD LNPTR

DWLP:
        CD SKIPWS       ; skip whitespace
        LHLD LNPTR
        MOV A,M
        ORA A
        JZ DBEND
        CPI ';'
        JZ DBEND        ; comment

; Parse expression as word
        CD EXPR         ; get value -> HL
        MOV A,L
        CD OUTPUT       ; emit low byte
        MOV A,H
        CD OUTPUT       ; emit high byte

; Check for comma
        CD SKIPWS       ; skip whitespace
        LHLD LNPTR
        MOV A,M
        CPI ','
        JNZ DBEND
        INX H           ; skip comma
        SHLD LNPTR
        JMP DWLP

; ============================================================
; GO_DEFS - Parse DEFS directive
; Syntax: DEFS count (reserve bytes, output zeros)
; ============================================================
GODES:
        INX H           ; skip 'S' of DEFS
        SHLD LNPTR
        CD SKIPWS       ; skip whitespace
        CD EXPR         ; get count -> HL
        XCHG            ; DE = count

DSLP:
        MOV A,D
        ORA E
        JZ DBEND        ; count = 0
        XRA A           ; A = 0
        CD OUTPUT       ; emit zero byte
        DCX D           ; count--
        JMP DSLP

; ============================================================
; HEXLN - Parse hex bytes with symbols
; Token-based approach:
;   2 hex chars = byte
;   4 hex chars = word (little endian)
;   otherwise = label reference
; ============================================================
HEXLN:
        CALL SKIPWS
        LHLD LNPTR
        MOV A,M
        ORA A
        RZ              ; end of line
        CPI ';'
        RZ              ; comment

; Check for < (low byte prefix)
        CPI '<'
        JZ HXLO
; Check for > (high byte prefix)
        CPI '>'
        JZ HXHI

; Scan token: count length, check if all hex
        PUSH H          ; save token start
        MVI B,0         ; length counter
        MVI C,0         ; all-hex flag: 0=yes

; SCAN - scan loop
SCAN:
        MOV A,M
        ORA A
        JZ SCAND        ; end of string
        CPI ' '
        JZ SCAND
        CPI TAB
        JZ SCAND
        CPI ';'
        JZ SCAND

; Check if char is hex (preserve B,C)
        PUSH B
        CALL ISHEXA     ; CY=1 if not hex
        POP B
        JNC SCANH       ; is hex
        MVI C,1         ; mark non-hex
; SCANH - char was hex, continue
SCANH:
        INR B
        INX H
        JMP SCAN

; SCAND - scan done
SCAND:
        POP H           ; restore token start
; C=0 means all hex, B=length
        MOV A,C
        ORA A
        JNZ HXSYM       ; has non-hex = label
; All hex - check length
        MOV A,B
        CPI 2
        JZ PARB         ; 2 chars = byte
        CPI 4
        JZ PARW         ; 4 chars = word
; Not 2 or 4 = label
        JMP HXSYM

; PARB - Parse 2 hex chars as byte
PARB:
        MOV A,M
        CALL HEXVAL
        RLC
        RLC
        RLC
        RLC
        MOV B,A
        INX H
        MOV A,M
        CALL HEXVAL
        ORA B
        INX H
        SHLD LNPTR
        CALL OUTPUT
        JMP HEXLN

; PARW - Parse 4 hex chars as word (little endian)
; CAFE -> output FE then CA
; First 2 chars = high byte
PARW:
        MOV A,M
        CALL HEXVAL
        RLC
        RLC
        RLC
        RLC
        MOV B,A
        INX H
        MOV A,M
        CALL HEXVAL
        ORA B
        PUSH PSW        ; save high byte
        INX H
; Next 2 chars = low byte
        MOV A,M
        CALL HEXVAL
        RLC
        RLC
        RLC
        RLC
        MOV B,A
        INX H
        MOV A,M
        CALL HEXVAL
        ORA B
        INX H
        SHLD LNPTR
; Output low byte first
        CALL OUTPUT
        POP PSW
        CALL OUTPUT
        JMP HEXLN

; HX_LO - Low byte prefix (<SYMBOL)
HXLO:
        INX H
        SHLD LNPTR
        CALL LOOKUP
        MOV A,L
        CALL OUTPUT
        JMP HEXLN

; HX_HI - High byte prefix (>SYMBOL)
HXHI:
        INX H
        SHLD LNPTR
        CALL LOOKUP
        MOV A,H
        CALL OUTPUT
        JMP HEXLN

; HX_SYM - Label reference, output low then high
HXSYM:
        CALL LOOKUP
        MOV A,L
        CALL OUTPUT
        MOV A,H
        CALL OUTPUT
        JMP HEXLN

; ============================================================
; GETCHR - Buffered input
; Returns: A=char, CY=1 if EOF
; Preserves: B, H, L
; ============================================================
GETCHR:
        PUSH B
        PUSH H
        LDA ICNT
        ORA A
        JNZ GC1

; Buffer empty, read sector
        LXI D,IBUF
        MVI C,26        ; set DMA
        CALL BDOS
        LXI D,FCB
        MVI C,20        ; read seq
        CALL BDOS
        ORA A
        JNZ GCEOF
        MVI A,128
        STA ICNT
        LXI H,IBUF
        SHLD IPTR

GC1:
        LHLD IPTR
        MOV A,M
        INX H
        SHLD IPTR
        PUSH PSW
        LDA ICNT
        DCR A
        STA ICNT
        POP PSW
        ORA A
        JZ GCEOF        ; null=EOF
        CPI 1AH
        JZ GCEOF
        ORA A           ; clear carry
        POP H
        POP B
        RET

GCEOF:
        POP H
        POP B
        STC
        RET

; ============================================================
; ISHEX - Check if char at [LNPTR] is hex
; Returns: CY=1 if not hex
; ============================================================
ISHEX:
        LHLD LNPTR
        MOV A,M
; Fall through to ISHEX_A

; ISHEX_A - Check if char in A is hex (for second char validation)
; Returns: CY=1 if not hex, A may be modified (uppercased)
ISHEXA:
; Convert to uppercase
        CPI 'a'
        JC IH1
        CPI LZ1
        JNC IH1
        SUI 20H
IH1:
        CPI '0'
        RC              ; below '0'
        CPI L91
        JC IH2
        CPI 'A'
        RC
        CPI 'G'
        CMC
        RET
IH2:
        ORA A           ; clear CY
        RET

; ============================================================
; HEXVAL - Convert hex char in A to value
; ============================================================
HEXVAL:
        CPI 'a'
        JC HV1
        SUI 20H         ; uppercase
HV1:
        CPI 'A'
        JC HV2
        SUI 37H
        RET
HV2:
        SUI '0'
        RET

; ============================================================
; OUTPUT - Buffered output (pass 2 only)
; ============================================================
OUTPUT:
        PUSH PSW
        LDA PASS
        ORA A
        JZ OUTP1
        POP PSW

; Pass 2 - output byte
        PUSH H
        PUSH PSW
        LHLD OPTR
        POP PSW
        MOV M,A
        INX H
        SHLD OPTR
        LDA OCNT
        INR A
        STA OCNT
        CPI 128
        JZ OUTFUL
        POP H
        RET

; OUT_FULL - Buffer full, write sector
OUTFUL:
        CALL WRSEC
        LXI H,OBUF
        SHLD OPTR
        XRA A
        STA OCNT
        POP H
        RET

; OUT_P1 - Pass 1, just increment LOCTR
OUTP1:
        POP PSW
        PUSH H
        LHLD LOCTR
        INX H
        SHLD LOCTR
        POP H
        RET

; ============================================================
; FLUSH - Flush output buffer
; ============================================================
FLUSH:
        LDA OCNT
        ORA A
        RZ
        LHLD OPTR
FL1:
        LDA OCNT
        CPI 128
        JNC WRSEC
        MVI M,0
        INX H
        INR A
        STA OCNT
        JMP FL1

; WRSEC - Write sector
WRSEC:
        LXI D,OBUF
        MVI C,26
        CALL BDOS
        LXI D,OFCB
        MVI C,21        ; write seq
        CALL BDOS
        RET

; ============================================================
; NOFILE error
; ============================================================
NOFILE:
        LXI D,MNOF
        JMP XERROR

; DSKFUL error
DSKFUL:
        LXI D,MDSK
        JMP XERROR

; UNDEF error
UNDEF:
        LXI D,MUDF
; Fall through to XERROR

; XERROR - renamed from ERROR (E is a hex digit!)
XERROR:
        MVI C,9
        CALL BDOS
        JMP BOOT

; ============================================================
; Messages
; ============================================================
MNOF:
        4E 6F 20 66 69 6C 65 24         ; "No file$"
MDSK:
        44 69 73 6B 20 66 75 6C 6C 24   ; "Disk full$"
MUDF:
        55 6E 64 65 66 24               ; "Undef$"

; ============================================================
; DEFSYM - Define symbol
; HL = start of label in line buffer
; Value = current LOCTR
; ============================================================
DEFSYM:
; Symbol table at 2000, 8 bytes per entry (6 name + 2 value)
        PUSH H          ; label start
        LDA SYMCNT
; Calculate slot: SYMTAB + SYMCNT * 8 (16-bit to handle >32 symbols)
        MOV L,A
        MVI H,0
        DAD H           ; x2
        DAD H           ; x4
        DAD H           ; x8
        LXI D,SYMTAB
        DAD D
        XCHG            ; DE = slot address
        POP H           ; label start

; Copy up to 6 chars of label to slot
        MVI B,6
DS1:
        MOV A,M
        CPI ':'
        JZ DS2          ; end of label
; Uppercase
        CPI 'a'
        JC DS1A
        CPI LZ1
        JNC DS1A
        SUI 20H
DS1A:
        STAX D
        INX D
        INX H
        DCR B
        JNZ DS1

; DS2 - Pad with spaces if needed
DS2:
        MOV A,L
; Actually check B
        MOV A,B
        ORA A
        JZ DS3
        MVI A,' '
DS2A:
        STAX D
        INX D
        DCR B
        JNZ DS2A

; DS3 - Store value (LOCTR)
DS3:
        LHLD LOCTR
        MOV A,L
        STAX D
        INX D
        MOV A,H
        STAX D

; Increment symbol count
        LDA SYMCNT
        INR A
        STA SYMCNT
        RET

; ============================================================
; LOOKUP - Look up symbol, advance LNPTR
; Returns: HL = value
; ============================================================
LOOKUP:
; Read symbol from line into temp, then search
        LHLD LNPTR
        LXI D,TOKBUF
        MVI B,6

; LK0 - Copy symbol to TOKBUF
LK0:
        MOV A,M
; Check for end of symbol (not alphanumeric)
        CPI '0'
        JC LK0E         ; end
        CPI L91
        JC LK0C         ; is digit
; Uppercase
        CPI 'a'
        JC LK0B
        CPI LZ1
        JNC LK0B
        SUI 20H
; LK0B - Check if letter
LK0B:
        CPI 'A'
        JC LK0E
        CPI LZU1
        JNC LK0E
; LK0C - Copy char
LK0C:
        STAX D
        INX D
        INX H
        DCR B
        JNZ LK0
; LK0D - Skip remaining symbol chars (letters only)
LK0D:
        MOV A,M
        ANI 0DFH         ; uppercase for letter check
        CPI 'A'
        JC LK1          ; not letter, done
        CPI LZU1
        JNC LK1         ; not letter, done
        INX H
        C3 LK0D         ; skip this letter, loop

; LK0E - End of symbol, pad with spaces
LK0E:
        MOV A,B
        ORA A
        JZ LK1          ; done padding
        MVI A,' '
        STAX D
        INX D
        DCR B
        JMP LK0E        ; loop

; LK1 - Save updated line pointer
LK1:
        SHLD LNPTR

; Search symbol table
        LXI H,SYMTAB
        LDA SYMCNT
        ORA A
        JZ LKNF         ; not found
        MOV B,A

; LK2 - Compare entry with TOKBUF
LK2:
        PUSH H
        LXI D,TOKBUF
        MVI C,6
; LK3
LK3:
        LDAX D
        CMP M
        JNZ LK4         ; not match
        INX D
        INX H
        DCR C
        JNZ LK3
; Match found!
; HL now points to value low byte
        MOV A,M
        INX H
        MOV H,M
        MOV L,A
        POP D           ; discard saved HL
        RET

; LK4 - No match, try next
LK4:
        POP H
; Advance to next entry (8 bytes)
        LXI D,8
        DAD D
        DCR B
        JNZ LK2

; LK_NF - Not found
LKNF:
        LDA PASS
        ORA A
        JNZ UNDEF       ; pass 2 - error
; Pass 1 - return 0
        LXI H,0
        RET

; ============================================================
; EXPR - Simple expression evaluator
; Returns: HL = value
; ============================================================
EXPR:
        CALL SKIPWS
        LHLD LNPTR
        MOV A,M

; Check for $ prefix (hex)
        CPI '$'
        JZ EXHEX

; Check for digit
        CPI '0'
        JC LOOKUP       ; not digit = symbol
        CPI L91
        JNC LOOKUP      ; not digit = symbol

; Parse number (hex with H suffix)
        LXI H,0
        LHLD LNPTR
; Use DE for accumulator
        PUSH H
        LXI H,0
        XCHG
        POP H

; EX_N1
EXN1:
        MOV A,M
; Uppercase
        CPI 'a'
        JC EXN1A
        CPI LZ1
        JNC EXN1A
        SUI 20H
; EX_N1A
EXN1A:
; Check for H suffix (end of hex)
        CPI 'H'
        JZ EXNH         ; hex done
; Check for digit 0-9
        CPI '0'
        JC EXDONE
        CPI L91
        JC EXDIG
; Check for A-F
        CPI 'A'
        JC EXDONE
        CPI 'G'
        JNC EXDONE

; EX_DIG - Is hex digit
EXDIG:
        INX H
        SHLD LNPTR
; Shift DE left 4, add digit
        PUSH H
        MOV H,D
        MOV L,E
        DAD H
        DAD H
        DAD H
        DAD H
        XCHG
        POP H
; Add digit value
        MOV A,M         ; note: we advanced, so wrong char
        DCX H           ; go back
        MOV A,M         ; get correct char
        INX H
        CPI 'A'
        JC EXD09
        SUI 37H
        JMP EXDAD
; EX_D09
EXD09:
        SUI '0'
; EX_DAD
EXDAD:
        ADD E
        MOV E,A
        JMP EXN1

; EX_DONE - Return DE as result
EXDONE:
        XCHG
        RET

; EX_NH - 'H' found, skip it and return
EXNH:
        INX H
        SHLD LNPTR
        XCHG
        RET

; EX_HEX - $XX hex format
EXHEX:
        INX H
        SHLD LNPTR
        LXI H,0
        XCHG
        LHLD LNPTR

; EXH1
EXH1:
        MOV A,M
        CPI 'a'
        JC EXH1A
        CPI LZ1
        JNC EXH1A
        SUI 20H
; EXH1A
EXH1A:
        CPI '0'
        JC EXDONE
        CPI L91
        JC EXHDG
        CPI 'A'
        JC EXDONE
        CPI 'G'
        JNC EXDONE
; EXH_DG
EXHDG:
        INX H
        SHLD LNPTR
        PUSH H
        MOV H,D
        MOV L,E
        DAD H
        DAD H
        DAD H
        DAD H
        XCHG
        POP H
        DCX H
        MOV A,M
        INX H
        CPI 'A'
        JC EXH09
        SUI 37H
        JMP EXHAD
; EXH_09
EXH09:
        SUI '0'
; EXH_AD
EXHAD:
        ADD E
        MOV E,A
        JMP EXH1

; ============================================================
; CHEQU - Check if current position is "EQU" (case-insensitive)
; Input: HL = current position (from LNPTR)
; Output: A = 1 if EQU found (LNPTR advanced past it), 0 otherwise
; ============================================================
CHEQU:
        MOV A,M
        ANI 0DFH        ; uppercase
        CPI 'E'
        JNZ CHENO
        INX H
        MOV A,M
        ANI 0DFH
        CPI 'Q'
        JNZ CHENO
        INX H
        MOV A,M
        ANI 0DFH
        CPI 'U'
        JNZ CHENO
        ; Found EQU!
        INX H
        SHLD LNPTR
        MVI A,1
        RET
CHENO:
        XRA A
        RET

; ============================================================
; DEFEQU - Define symbol with explicit value
; Input: HL = label start, DE = value to store
; Like DEFSYM but terminates name at whitespace, uses DE for value
; ============================================================
DEFEQU:
        PUSH D          ; save value
        PUSH H          ; save label start
        ; Calculate slot: SYMTAB + SYMCNT * 8
        LDA SYMCNT
        MOV L,A
        MVI H,0
        DAD H           ; x2
        DAD H           ; x4
        DAD H           ; x8
        LXI D,SYMTAB
        DAD D
        XCHG            ; DE = slot address
        POP H           ; label start
        ; Copy up to 6 chars until whitespace
        MVI B,6
DEQ1:
        MOV A,M
        CPI ' '
        JZ DEQ2         ; end of name
        CPI TAB
        JZ DEQ2
        ; Uppercase
        CPI 'a'
        JC DEQ1A
        CPI LZ1
        JNC DEQ1A
        SUI 20H
DEQ1A:
        STAX D
        INX D
        INX H
        DCR B
        JNZ DEQ1
; DEQ2 - Pad with spaces
DEQ2:
        MOV A,B
        ORA A
        JZ DEQ3
        MVI A,' '
DEQ2A:
        STAX D
        INX D
        DCR B
        JNZ DEQ2A
; DEQ3 - Store value from stack
DEQ3:
        POP H           ; saved value
        MOV A,L
        STAX D
        INX D
        MOV A,H
        STAX D
        ; Increment symbol count
        LDA SYMCNT
        INR A
        STA SYMCNT
        RET

; ============================================================
; REGISTER TABLE - Single registers (char, code)
; Code: B=0, C=1, D=2, E=3, H=4, L=5, M=6, A=7
; ============================================================
REGTAB:
        DEFB 42H, 00    ; 'B', 0
        DEFB 43H, 01    ; 'C', 1
        DEFB 44H, 02    ; 'D', 2
        DEFB 45H, 03    ; 'E', 3
        DEFB 48H, 04    ; 'H', 4
        DEFB 4CH, 05    ; 'L', 5
        DEFB 4DH, 06    ; 'M', 6
        DEFB 41H, 07    ; 'A', 7
        DEFB 00         ; End marker

; ============================================================
; MNEMONIC TABLE
; Format: 4 bytes name (space-padded), 1 byte opcode, 1 byte format
; Format types:
;   0 = FMT_NONE  - no operand
;   1 = FMT_REG   - single reg dest (bits 3-5): INR, DCR
;   2 = FMT_RSRC  - single reg src (bits 0-2): ADD, ORA, CMP, ANA, XRA
;   3 = FMT_REGREG - MOV r,r (dest 3-5, src 0-2)
;   4 = FMT_RP    - reg pair (bits 4-5): INX, DCX, DAD
;   5 = FMT_RP16  - reg pair + 16-bit imm: LXI
;   6 = FMT_IMM8  - 8-bit immediate: CPI, ANI, SUI, ORI, ADI
;   7 = FMT_IMM16 - 16-bit address: JMP, CALL, JZ, JNZ, JC, JNC
;   8 = FMT_MVIREG - MVI r,n (reg bits 3-5, then imm8)
;   9 = FMT_ADDR  - fixed opcode + 16-bit addr: LDA, STA, LHLD, SHLD
;  10 = FMT_LDAXST - LDAX/STAX rp (bits 4-5, B or D only)
;  11 = FMT_PUSH  - PUSH/POP rp (bits 4-5, PSW=3)
; ============================================================
MNTAB:
; Group 0: No operand (FMT_NONE = 0)
        DEFB 'RET ', 0C9H, 00
        DEFB 'RZ  ', 0C8H, 00
        DEFB 'RNZ ', 0C0H, 00
        DEFB 'RC  ', 0D8H, 00
        DEFB 'RNC ', 0D0H, 00
        DEFB 'XCHG', 0EBH, 00
        DEFB 'STC ', 37H, 00
        DEFB 'CMC ', 3FH, 00
        DEFB 'RLC ', 07H, 00
        DEFB 'RRC ', 0FH, 00
        DEFB 'RAL ', 17H, 00
        DEFB 'RAR ', 1FH, 00
        DEFB 'NOP ', 00H, 00
        DEFB 'HLT ', 76H, 00
        DEFB 'CMA ', 2FH, 00
        DEFB 'DAA ', 27H, 00
        DEFB 'EI  ', 0FBH, 00
        DEFB 'DI  ', 0F3H, 00
        DEFB 'SPHL', 0F9H, 00
        DEFB 'PCHL', 0E9H, 00
        DEFB 'XTHL', 0E3H, 00
        DEFB 'RP  ', 0F0H, 00
        DEFB 'RM  ', 0F8H, 00
        DEFB 'RPE ', 0E8H, 00
        DEFB 'RPO ', 0E0H, 00
; Group 1: Single reg dest bits 3-5 (FMT_REG = 1)
        DEFB 'INR ', 04H, 01
        DEFB 'DCR ', 05H, 01
; Group 2: Single reg src bits 0-2 (FMT_RSRC = 2)
        DEFB 'ADD ', 80H, 02
        DEFB 'ADC ', 88H, 02
        DEFB 'SUB ', 90H, 02
        DEFB 'SBB ', 98H, 02
        DEFB 'ANA ', 0A0H, 02
        DEFB 'XRA ', 0A8H, 02
        DEFB 'ORA ', 0B0H, 02
        DEFB 'CMP ', 0B8H, 02
; Group 3: MOV r,r (FMT_REGREG = 3)
        DEFB 'MOV ', 40H, 03
; Group 4: Register pair bits 4-5 (FMT_RP = 4)
        DEFB 'INX ', 03H, 04
        DEFB 'DCX ', 0BH, 04
        DEFB 'DAD ', 09H, 04
; Group 5: LXI rp,nn (FMT_RP16 = 5)
        DEFB 'LXI ', 01H, 05
; Group 6: 8-bit immediate (FMT_IMM8 = 6)
        DEFB 'CPI ', 0FEH, 06
        DEFB 'ANI ', 0E6H, 06
        DEFB 'ORI ', 0F6H, 06
        DEFB 'XRI ', 0EEH, 06
        DEFB 'SUI ', 0D6H, 06
        DEFB 'SBI ', 0DEH, 06
        DEFB 'ADI ', 0C6H, 06
        DEFB 'ACI ', 0CEH, 06
        DEFB 'IN  ', 0DBH, 06
        DEFB 'OUT ', 0D3H, 06
; Group 7: 16-bit address (FMT_IMM16 = 7)
        DEFB 'JMP ', 0C3H, 07
        DEFB 'JZ  ', 0CAH, 07
        DEFB 'JNZ ', 0C2H, 07
        DEFB 'JC  ', 0DAH, 07
        DEFB 'JNC ', 0D2H, 07
        DEFB 'JP  ', 0F2H, 07
        DEFB 'JM  ', 0FAH, 07
        DEFB 'JPE ', 0EAH, 07
        DEFB 'JPO ', 0E2H, 07
        DEFB 'CALL', 0CDH, 07
        DEFB 'CZ  ', 0CCH, 07
        DEFB 'CNZ ', 0C4H, 07
        DEFB 'CC  ', 0DCH, 07
        DEFB 'CNC ', 0D4H, 07
        DEFB 'CP  ', 0F4H, 07
        DEFB 'CM  ', 0FCH, 07
        DEFB 'CPE ', 0ECH, 07
        DEFB 'CPO ', 0E4H, 07
; Group 8: MVI r,n (FMT_MVIREG = 8)
        DEFB 'MVI ', 06H, 08
; Group 9: Fixed opcode + 16-bit addr (FMT_ADDR = 9)
        DEFB 'LDA ', 3AH, 09
        DEFB 'STA ', 32H, 09
        DEFB 'LHLD', 2AH, 09
        DEFB 'SHLD', 22H, 09
; Group 10: LDAX/STAX rp (FMT_LDAXST = 10)
        DEFB 'LDAX', 0AH, 0AH
        DEFB 'STAX', 02H, 0AH
; Group 11: PUSH/POP (FMT_PUSH = 11)
        DEFB 'PUSH', 0C5H, 0BH
        DEFB 'POP ', 0C1H, 0BH
; End marker
        DEFB 00

; ============================================================
; CHKMNM - Check for and parse mnemonic
; If mnemonic found: parse operands, emit bytes, clear line
; If not found: return (fall through to HEXLN)
; ============================================================
CHKMNM:
        CD SKIPWS       ; skip whitespace
        LHLD LNPTR
        MOV A,M
        ORA A
        RZ              ; empty
        CPI ';'
        RZ              ; comment

; Copy 4 chars to TOKBUF, uppercase, space-pad
        LXI D,TOKBUF
        MVI B,4
CMN1:
        MOV A,M
        ORA A
        JZ CMN2
        CPI ' '
        JZ CMN2
        CPI TAB
        JZ CMN2
        ANI 0DFH         ; uppercase - safe, non-letters won't match
        STAX D
        INX D
        INX H
        DCR B
        JNZ CMN1
        JMP CMN3
; Pad with spaces
CMN2:
        MVI A,' '
CMN2A:
        STAX D
        INX D
        DCR B
        JNZ CMN2A

; Search mnemonic table
CMN3:
        LXI H,MNTAB
CMN4:
        MOV A,M         ; first char
        ORA A
        RZ              ; end of table, not found
; Compare 4 chars
        PUSH H          ; save table ptr
        LXI D,TOKBUF
        MVI B,4
CMN5:
        LDAX D
        CMP M
        JNZ CMN6
        INX D
        INX H
        DCR B
        JNZ CMN5
; Match! HL now points to opcode byte
        MOV A,M         ; opcode
        MOV C,A         ; save opcode in C
        INX H
        MOV B,M         ; format
        POP D           ; discard saved ptr
; Skip mnemonic in source line
        CD SKPMNM      ; skip past mnemonic
; Dispatch based on format in B (opcode saved in C)
        MOV A,B         ; format for dispatch
        ORA A
        JZ FMNONE       ; format 0
        CPI 1
        JZ FMREG
        CPI 2
        JZ FMRSRC
        CPI 3
        JZ FMRR
        CPI 4
        JZ FMRP
        CPI 5
        JZ FMRP16
        CPI 6
        JZ FMIMM8
        CPI 7
        JZ FMI16
        CPI 8
        JZ FMVIR
        CPI 9
        JZ FMI16        ; same as IMM16
        CPI 10
        JZ FMRP         ; same as RP
        CPI 11
        JZ FMPUSH
; Unknown format (shouldn't happen)
        RET

; CMN6 - No match, try next entry
CMN6:
        POP H           ; restore table ptr
        LXI D,6         ; entry size
        DAD D
        JMP CMN4

; ============================================================
; SKPMNM - Skip past mnemonic in source line
; Advances LNPTR past alphanumeric chars
; ============================================================
SKPMNM:
        LHLD LNPTR
SKM1:
        MOV A,M
        ORA A
        JZ SKM2
        CPI ' '
        JZ SKM2
        CPI TAB
        JZ SKM2
        CPI ','
        JZ SKM2
        INX H
        JMP SKM1
SKM2:
        SHLD LNPTR
        RET

; ============================================================
; CLRLN - Clear line so HEXLN won't process
; ============================================================
CLRLN:
        LXI H,LINBUF
        MVI M,0
        SHLD LNPTR
        RET

; ============================================================
; SKPCOM - Skip comma and whitespace
; Skips whitespace, then comma if present, then whitespace
; ============================================================
SKPCOM:
        CD SKIPWS       ; skip leading whitespace
        LHLD LNPTR
        MOV A,M
        CPI ','
        JNZ SKIPWS
        INX H           ; skip comma
        SHLD LNPTR
        C3 SKIPWS       ; skip trailing whitespace

; ============================================================
; Format Handlers
; Entry: A = base opcode
; ============================================================

; FMT_NONE - No operand, just emit opcode
FMNONE:
        MOV A,C         ; restore opcode from C
        CD OUTPUT       ; emit opcode
        C3 CLRLN      ; clear line, done

; FMT_REG - Single register in bits 3-5 (INR, DCR)
; Syntax: INR A, DCR B, etc.
FMREG:
        MOV A,C         ; restore opcode from C
        PUSH PSW        ; save opcode
        CD SKIPWS       ; skip whitespace
        CD GETREG       ; get register code in A
        RLC
        RLC
        RLC             ; shift left 3 = bits 3-5
        MOV B,A
        POP PSW         ; restore opcode
        ORA B           ; combine
        CD OUTPUT       ; emit opcode
        C3 CLRLN      ; done

; FMT_RSRC - Single register in bits 0-2 (ADD, ORA, CMP, etc.)
; Syntax: ADD E, ORA A, etc.
FMRSRC:
        MOV A,C         ; restore opcode from C
        PUSH PSW        ; save opcode
        CD SKIPWS       ; skip whitespace
        CD GETREG       ; get register code in A (0-7)
        MOV B,A
        POP PSW         ; restore opcode
        ORA B           ; combine
        CD OUTPUT       ; emit opcode
        C3 CLRLN      ; done

; FMT_REGREG - MOV r,r (dest bits 3-5, src bits 0-2)
; Syntax: MOV A,B
FMRR:
        MOV A,C         ; restore opcode from C
        PUSH PSW        ; save base opcode
        CD SKIPWS       ; skip whitespace
        CD GETREG       ; get dest register
        RLC
        RLC
        RLC             ; shift to bits 3-5
        PUSH PSW        ; save dest
        CD SKPCOM       ; skip comma
        CD GETREG       ; get src register (0-7)
        MOV B,A         ; src in B
        POP PSW         ; dest in bits 3-5
        ORA B           ; add src
        MOV B,A         ; combined regs
        POP PSW         ; base opcode
        ORA B           ; final opcode
        CD OUTPUT       ; emit opcode
        C3 CLRLN      ; done

; FMT_RP - Register pair in bits 4-5 (INX, DCX, DAD)
; Syntax: INX H, DCX D, etc.
FMRP:
        MOV A,C         ; restore opcode from C
        PUSH PSW        ; save opcode
        CD SKIPWS       ; skip whitespace
        CD GETRP        ; get reg pair code (0-3)
        RLC
        RLC
        RLC
        RLC             ; shift to bits 4-5
        MOV B,A
        POP PSW
        ORA B
        CD OUTPUT       ; emit opcode
        C3 CLRLN      ; done

; FMT_RP16 - LXI rp,nn
; Syntax: LXI H,1234H
FMRP16:
        MOV A,C         ; restore opcode from C
        PUSH PSW        ; save opcode
        CD SKIPWS       ; skip whitespace
        CD GETRP        ; get reg pair (0-3)
        RLC
        RLC
        RLC
        RLC
        MOV B,A
        POP PSW
        ORA B
        CD OUTPUT       ; emit opcode
        CD SKPCOM       ; skip comma
        CD EXPR         ; get 16-bit value
        MOV A,L
        CD OUTPUT       ; emit low byte
        MOV A,H
        CD OUTPUT       ; emit high byte
        C3 CLRLN      ; done

; FMT_IMM8 - 8-bit immediate (CPI, ANI, etc.)
; Syntax: CPI 42H
FMIMM8:
        MOV A,C         ; restore opcode from C
        CD OUTPUT       ; emit opcode
        CD SKIPWS       ; skip whitespace
        CD EXPR         ; get value
        MOV A,L         ; low byte only
        CD OUTPUT       ; emit immediate
        C3 CLRLN      ; done

; FMT_IMM16 - 16-bit address (JMP, CALL, etc.)
; Syntax: JMP LABEL, CALL 1234H
FMI16:
        MOV A,C         ; restore opcode from C
        CD OUTPUT       ; emit opcode
        CD SKIPWS       ; skip whitespace
        CD EXPR         ; get address
        MOV A,L
        CD OUTPUT       ; emit low byte
        MOV A,H
        CD OUTPUT       ; emit high byte
        C3 CLRLN      ; done

; FMT_MVIREG - MVI r,n (reg bits 3-5, then immediate)
; Syntax: MVI A,42H
FMVIR:
        MOV A,C         ; restore opcode from C
        PUSH PSW        ; save base opcode 06H
        CD SKIPWS       ; skip whitespace
        CD GETREG       ; get register (0-7)
        RLC
        RLC
        RLC             ; shift to bits 3-5
        MOV B,A
        POP PSW
        ORA B
        CD OUTPUT       ; emit opcode
        CD SKPCOM       ; skip comma
        CD EXPR         ; get immediate value
        MOV A,L
        CD OUTPUT       ; emit immediate
        C3 CLRLN      ; done

; FMT_PUSH - PUSH/POP (reg pair bits 4-5, PSW=3)
; Syntax: PUSH H, POP PSW
FMPUSH:
        MOV A,C         ; restore opcode from C
        PUSH PSW        ; save opcode
        CD SKIPWS       ; skip whitespace
        CD GTRPSH    ; get reg pair for push/pop (B,D,H,PSW)
        RLC
        RLC
        RLC
        RLC
        MOV B,A
        POP PSW
        ORA B
        CD OUTPUT       ; emit opcode
        C3 CLRLN      ; done

; ============================================================
; GETREG - Get register code from source
; Returns: A = register code (0-7)
; Advances LNPTR past the register letter
; ============================================================
GETREG:
        LHLD LNPTR
        MOV A,M
        ANI 0DFH        ; uppercase
        MOV B,A         ; save char
        INX H
        SHLD LNPTR      ; advance past register
; Search for B in REGTAB
        LXI H,REGTAB
GREGLP:
        MOV A,M         ; char from table
        ORA A
        JZ RET0
        CMP B           ; compare with input char
        JNZ GREGN
; Found
        INX H
        MOV A,M         ; code
        RET
GREGN:
        INX H
        INX H           ; skip to next entry
        JMP GREGLP

; ============================================================
; Shared return routines (must be before GETRP/GTRPSH for forward refs)
; ============================================================
RET0:   XRA A
        RET
RET1:   MVI A,1
        RET
RET2:   MVI A,2
        RET

; ============================================================
; GETRP - Get register pair code from source
; Returns: A = pair code (0=B, 1=D, 2=H, 3=SP)
; ============================================================
GETRP:
        LHLD LNPTR
        MOV A,M
        ANI 0DFH        ; uppercase
        MOV B,A         ; first char
        INX H
        SHLD LNPTR
; Check for single-letter pairs: B, D, H
        MOV A,B
        CPI 'B'
        JZ RET0
        CPI 'D'
        JZ RET1
        CPI 'H'
        JZ RET2
; Check for SP
        CPI 'S'
        JNZ RET0
        LHLD LNPTR
        MOV A,M
        ANI 0DFH         ; uppercase
        CPI 'P'
        JNZ RET0
        INX H
        SHLD LNPTR
        MVI A,3
        RET

; ============================================================
; GTRPSH - Get register pair for PUSH/POP (includes PSW)
; Returns: A = pair code (0=B, 1=D, 2=H, 3=PSW)
; ============================================================
GTRPSH:
        LHLD LNPTR
        MOV A,M
        ANI 0DFH        ; uppercase
        MOV B,A
        INX H
        SHLD LNPTR
; Check B, D, H
        MOV A,B
        CPI 'B'
        JZ RET0
        CPI 'D'
        JZ RET1
        CPI 'H'
        JZ RET2
; Check for PSW
        CPI 'P'
        JNZ RET0
        LHLD LNPTR
        MOV A,M
        ANI 0DFH         ; uppercase
        CPI 'S'
        JNZ RET0
        INX H
        MOV A,M
        ANI 0DFH
        CPI 'W'
        JNZ RET0
        INX H
        SHLD LNPTR
; Return 3 for PSW
        MVI A,3
        RET

        END
