;===============================================================================
; STAGE0 - Minimal Hex Loader for spazm8080 Bootstrap
;===============================================================================
; Input:  FILE.HEX - hex bytes separated by whitespace, ';' starts comment
; Output: FILE.COM - raw binary
;
; Example input:
;   ; This is a comment
;   21 00 01    ; LXI H,0100H
;   C3 00 00    ; JMP 0
;
; Usage: STAGE0 FILENAME   (reads FILENAME.HEX, writes FILENAME.COM)
;===============================================================================

        ORG     0100H

;-------------------------------------------------------------------------------
; Constants
;-------------------------------------------------------------------------------
BDOS    EQU     0005H           ; BDOS entry point
WBOOT   EQU     0000H           ; Warm boot
FCB     EQU     005CH           ; Default FCB
DMA     EQU     0080H           ; Default DMA

; BDOS functions
PRINT   EQU     9               ; Print $-terminated string
OPEN    EQU     15              ; Open file
CLOSE   EQU     16              ; Close file
DELETE  EQU     19              ; Delete file
READ    EQU     20              ; Read sequential
WRITE   EQU     21              ; Write sequential
MAKE    EQU     22              ; Create file
SETDMA  EQU     26              ; Set DMA address

;-------------------------------------------------------------------------------
; Entry Point
;-------------------------------------------------------------------------------
START:
        ; Set input file extension to HEX
        LXI     H,FCB+9         ; 21 65 00
        MVI     M,'H'           ; 36 48
        INX     H               ; 23
        MVI     M,'E'           ; 36 45
        INX     H               ; 23
        MVI     M,'X'           ; 36 58

        ; Open input file
        LXI     D,FCB           ; 11 5C 00
        MVI     C,OPEN          ; 0E 0F
        CALL    BDOS            ; CD 05 00
        INR     A               ; 3C       (FF->0 = error)
        JZ      NOFILE          ; CA xx xx

        ; Copy FCB to OFCB (9 bytes: drive + filename)
        LXI     H,FCB           ; 21 5C 00
        LXI     D,OFCB          ; 11 xx xx
        MVI     B,9             ; 06 09
COPY:   MOV     A,M             ; 7E
        STAX    D               ; 12
        INX     H               ; 23
        INX     D               ; 13
        DCR     B               ; 05
        JNZ     COPY            ; C2 xx xx

        ; Set output extension to COM
        MVI     A,'C'           ; 3E 43
        STAX    D               ; 12
        INX     D               ; 13
        MVI     A,'O'           ; 3E 4F
        STAX    D               ; 12
        INX     D               ; 13
        MVI     A,'M'           ; 3E 4D
        STAX    D               ; 12
        INX     D               ; 13

        ; Zero rest of output FCB (24 bytes)
        MVI     B,24            ; 06 18
ZERO:   XRA     A               ; AF
        STAX    D               ; 12
        INX     D               ; 13
        DCR     B               ; 05
        JNZ     ZERO            ; C2 xx xx

        ; Delete existing output file (ignore errors)
        LXI     D,OFCB          ; 11 xx xx
        MVI     C,DELETE        ; 0E 13
        CALL    BDOS            ; CD 05 00

        ; Create output file
        LXI     D,OFCB          ; 11 xx xx
        MVI     C,MAKE          ; 0E 16
        CALL    BDOS            ; CD 05 00
        INR     A               ; 3C
        JZ      DSKFUL          ; CA xx xx

        ; Initialize pointers
        LXI     H,OBUF          ; 21 xx xx
        SHLD    OPTR            ; 22 xx xx
        XRA     A               ; AF
        STA     OCNT            ; 32 xx xx
        STA     ICNT            ; 32 xx xx

;-------------------------------------------------------------------------------
; Main Loop
;-------------------------------------------------------------------------------
MAIN:   CALL    GETCHR          ; CD xx xx
        JC      DONE            ; DA xx xx

        CPI     ';'             ; FE 3B     Comment?
        JZ      SKIPCMT         ; CA xx xx

        CPI     ' '             ; FE 20     Space?
        JZ      MAIN            ; CA xx xx
        CPI     09H             ; FE 09     Tab?
        JZ      MAIN            ; CA xx xx
        CPI     0DH             ; FE 0D     CR?
        JZ      MAIN            ; CA xx xx
        CPI     0AH             ; FE 0A     LF?
        JZ      MAIN            ; CA xx xx

        ; Must be hex digit - get high nibble
        CALL    HEXVAL          ; CD xx xx
        JC      SYNERR          ; DA xx xx
        RLC                     ; 07
        RLC                     ; 07
        RLC                     ; 07
        RLC                     ; 07
        MOV     B,A             ; 47        Save high nibble

        ; Get low nibble
        CALL    GETCHR          ; CD xx xx
        JC      SYNERR          ; DA xx xx
        CALL    HEXVAL          ; CD xx xx
        JC      SYNERR          ; DA xx xx
        ORA     B               ; B0        Combine nibbles
        CALL    OUTPUT          ; CD xx xx
        JMP     MAIN            ; C3 xx xx

;-------------------------------------------------------------------------------
; Skip Comment - consume until newline
;-------------------------------------------------------------------------------
SKIPCMT:
        CALL    GETCHR          ; CD xx xx
        JC      DONE            ; DA xx xx
        CPI     0AH             ; FE 0A
        JNZ     SKIPCMT         ; C2 xx xx
        JMP     MAIN            ; C3 xx xx

;-------------------------------------------------------------------------------
; Done - flush and exit
;-------------------------------------------------------------------------------
DONE:   CALL    FLUSH           ; CD xx xx
        LXI     D,OFCB          ; 11 xx xx
        MVI     C,CLOSE         ; 0E 10
        CALL    BDOS            ; CD 05 00
        LXI     D,FCB           ; 11 5C 00
        MVI     C,CLOSE         ; 0E 10
        CALL    BDOS            ; CD 05 00
        JMP     WBOOT           ; C3 00 00

;-------------------------------------------------------------------------------
; GETCHR - Get character from input file
;-------------------------------------------------------------------------------
; Output: A = character, CY set on EOF
;-------------------------------------------------------------------------------
GETCHR: LDA     ICNT            ; 3A xx xx
        ORA     A               ; B7
        JNZ     GC1             ; C2 xx xx

        ; Need to read new sector
        LXI     D,IBUF          ; 11 xx xx
        MVI     C,SETDMA        ; 0E 1A
        CALL    BDOS            ; CD 05 00
        LXI     D,FCB           ; 11 5C 00
        MVI     C,READ          ; 0E 14
        CALL    BDOS            ; CD 05 00
        ORA     A               ; B7
        JNZ     GC2             ; C2 xx xx   EOF or error
        MVI     A,128           ; 3E 80
        STA     ICNT            ; 32 xx xx
        LXI     H,IBUF          ; 21 xx xx
        SHLD    IPTR            ; 22 xx xx

GC1:    LHLD    IPTR            ; 2A xx xx
        MOV     A,M             ; 7E
        INX     H               ; 23
        SHLD    IPTR            ; 22 xx xx
        PUSH    PSW             ; F5
        LDA     ICNT            ; 3A xx xx
        DCR     A               ; 3D
        STA     ICNT            ; 32 xx xx
        POP     PSW             ; F1
        ORA     A               ; B7        Check for 0 (LOLOS EOF) + clear CY
        JZ      GC2             ; CA xx xx  EOF if null
        CPI     1AH             ; FE 1A     CP/M EOF marker
        JZ      GC2             ; CA xx xx  EOF if 0x1A
        RET                     ; C9        Return with char, CY=0

GC2:    STC                     ; 37
        RET                     ; C9

;-------------------------------------------------------------------------------
; HEXVAL - Convert hex character to value
;-------------------------------------------------------------------------------
; Input:  A = ASCII character
; Output: A = value (0-15), CY set if not hex
;-------------------------------------------------------------------------------
HEXVAL: CPI     '0'             ; FE 30
        JC      HVERR           ; DA xx xx
        CPI     '9'+1           ; FE 3A
        JC      HV1             ; DA xx xx   0-9
        CPI     'A'             ; FE 41
        JC      HVERR           ; DA xx xx
        CPI     'F'+1           ; FE 47
        JC      HV2             ; DA xx xx   A-F
        CPI     'a'             ; FE 61
        JC      HVERR           ; DA xx xx
        CPI     'f'+1           ; FE 67
        JNC     HVERR           ; D2 xx xx
        SUI     'a'-10          ; D6 57     a-f
        RET                     ; C9
HV1:    SUI     '0'             ; D6 30
        RET                     ; C9
HV2:    SUI     'A'-10          ; D6 37
        RET                     ; C9
HVERR:  STC                     ; 37
        RET                     ; C9

;-------------------------------------------------------------------------------
; OUTPUT - Output byte to buffer
;-------------------------------------------------------------------------------
; Input: A = byte to output
;-------------------------------------------------------------------------------
OUTPUT: PUSH    PSW             ; F5
        LHLD    OPTR            ; 2A xx xx
        POP     PSW             ; F1
        MOV     M,A             ; 77
        INX     H               ; 23
        SHLD    OPTR            ; 22 xx xx
        LDA     OCNT            ; 3A xx xx
        INR     A               ; 3C
        STA     OCNT            ; 32 xx xx
        CPI     128             ; FE 80
        RNZ                     ; C0

        ; Buffer full - write sector
        CALL    WRSEC           ; CD xx xx
        LXI     H,OBUF          ; 21 xx xx
        SHLD    OPTR            ; 22 xx xx
        XRA     A               ; AF
        STA     OCNT            ; 32 xx xx
        RET                     ; C9

;-------------------------------------------------------------------------------
; FLUSH - Flush output buffer (pad with zeros)
;-------------------------------------------------------------------------------
FLUSH:  LDA     OCNT            ; 3A xx xx
        ORA     A               ; B7
        RZ                      ; C8        Nothing to flush

        ; Pad remaining bytes with zero
        LHLD    OPTR            ; 2A xx xx
FL1:    LDA     OCNT            ; 3A xx xx
        CPI     128             ; FE 80
        JNC     FL2             ; D2 xx xx
        MVI     M,0             ; 36 00
        INX     H               ; 23
        INR     A               ; 3C
        STA     OCNT            ; 32 xx xx
        JMP     FL1             ; C3 xx xx
FL2:    ; Fall through to WRSEC

;-------------------------------------------------------------------------------
; WRSEC - Write output sector
;-------------------------------------------------------------------------------
WRSEC:  LXI     D,OBUF          ; 11 xx xx
        MVI     C,SETDMA        ; 0E 1A
        CALL    BDOS            ; CD 05 00
        LXI     D,OFCB          ; 11 xx xx
        MVI     C,WRITE         ; 0E 15
        CALL    BDOS            ; CD 05 00
        RET                     ; C9

;-------------------------------------------------------------------------------
; Error Handlers
;-------------------------------------------------------------------------------
NOFILE: LXI     D,MNOF          ; 11 xx xx
        JMP     ERROR           ; C3 xx xx
DSKFUL: LXI     D,MDSK          ; 11 xx xx
        JMP     ERROR           ; C3 xx xx
SYNERR: LXI     D,MSYN          ; 11 xx xx
ERROR:  MVI     C,PRINT         ; 0E 09
        CALL    BDOS            ; CD 05 00
        JMP     WBOOT           ; C3 00 00

;-------------------------------------------------------------------------------
; Messages
;-------------------------------------------------------------------------------
MNOF:   DB      'No file$'
MDSK:   DB      'Disk full$'
MSYN:   DB      'Syntax$'

;-------------------------------------------------------------------------------
; Data Area
;-------------------------------------------------------------------------------
IPTR:   DS      2               ; Input buffer pointer
ICNT:   DS      1               ; Input buffer count
OPTR:   DS      2               ; Output buffer pointer
OCNT:   DS      1               ; Output buffer count
IBUF:   DS      128             ; Input buffer
OBUF:   DS      128             ; Output buffer
OFCB:   DS      36              ; Output FCB

        END
