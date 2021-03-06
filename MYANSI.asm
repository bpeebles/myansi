;
; MYANSI.8
;
; Byron Peebles
;
; It only acts on cursor and colour commands.
; It's much faster then ANSI.SYS. For normal text (i.e. no ANSI commands)
; MyANSI is faster then the default INT 29 that comes with DOS (DOS 6.22
; any way). By the way, the default INT 29 with DOS just calls the BIOS
; video interrupt, service 0Eh (TTY Characcter Output).
;
; In the comments for some of the procdures I have a comment like this:
; ESC[PnA
; That shows how it should be used from the incoming text.
; Pn = Numeric parameter. In decimal (all will be).
; Ps = Selective parameter. You can have more then one.
; PL = Line parameter.
; Pc = Column parameter.
;
; All the times I use bit refs (i.e. bit 3) I will be using a zero based
; system. Bit 0 is the first one, bit 7 is the last in a byte.
;
; If you like this program or not, give me some e-mail.
;
; If you can any qustions about the code (I know I didn't comment it fully)
; you can e-mail me at: byron.peebles@gmail.com
;
; This code is released under the MIT license, see LICENSE.txt for details.
;

;
; If you set debug to 1, it will not make it's self a TSR, it will print a
; string called "TestStr" through the ANSI driver. There will be no new
; interrupt of any kind.
;
debug equ 0
;
; Some old junk left over from when the ansi part didn't work, but I still
; wanted to use the TTY part of it. Keep it set to one if you want to use
; ANSI.
;
useansi equ 1
;
;
myscroll equ 1
dwordscroll equ 1
;
; Just some macros
;
PUTS MACRO
  MOV DX,OFFSET #1
  CALL PUT_STRING
#EM

; Number 1 is the number of lines to scroll, and number 2 is the color.
ScrUp macro
        mov     al,#1
        mov     bh,#2
        mov     ah,06
        xor     cx,cx
        mov     dh,[MaxY]
        mov     dl,[MaxX]
        int     10h
#EM
;
; Jump to the start of the start-up code.
  JMP START
BEGIN:

INT_NUM EQU     29H

SIGNATURE       DB      'ZBzPpD'
SIGLEN  EQU     $ - SIGNATURE
;COPYRIGHT       DB      'Coded by Skynxnex [LaC]'
; DATA Area
OLD_INT_29      DW      ?,?
; The current color.
COLOR   DB      7  ; We always start out with color 7 (white FG; black BG).
;
MaxX    DB      79
MaxY    db      49
;
vmode db 3
;
#IF useansi
;
Current dw SeeIfBegin
;
ColorTable:
ForColor        db      0,4,2,6,1,5,3,7  ; A look up table to convert ANSI
                                         ; colours to the values by the video
                                         ; card.
;
db 7,7
;
BackColor       db      0,4 shl 4,2 shl 4,6 shl 4
                db      1 shl 4,5 shl 4,3 shl 4,7 shl 4
;
; Used by ESC[s and ESC[u
oldx            db      ?
oldy            db      ?
;
; Used to save the numbers
Nums    db      8 dup(?)
NumPtr  dw      Nums
;
; Used to build up a string to convert into a number
String  db      4 dup(?)
StrPtr  dw      String
;
#endif
;
; Returns with X in DL and Y in DH.
;
GetXY:
  PUSH 0
  POP ES
  MOV DX,ES:[450h]
  RET

; MoveXY - Call with the X value in DL, and the Y value in DH

MoveXY:
  mov ax,dx             ; 1, Number of clocks (best case)
  xor bx,bx             ; 1
  mov bl,ah             ; 1
  mov cx,bx             ; 1
  shl bx,6              ; 3
  shl cx,4              ; 3
  add cx,bx             ; 1
  xor ah,ah             ; 1
  add cx,ax             ; 1
  push dx               ; 1
  mov dx,3d4h           ; 1
  mov al,0eh            ; 1
  mov ah,ch             ; 1
  out dx,ax             ; 16 (by far best case - prolly more like 30)
  inc al                ; 1
  mov ah,cl             ; 1
  out dx,ax             ; 16
  push 0
  pop es
  pop dx                ; 1
  mov es:[450h],dx      ; 2
  RET                   ; 5 - around 60, for all of it
;
; Call with the X,Y cords in DX.
; Returns with ES:[DI]
; Messes up most of the regs.
;
MakeOffset:
        xor     ax,ax
        mov     al,dl
        shr     dx,8
        mov     bx,dx
        shl     bx,6
        shl     dx,4
        add     dx,bx
        add     ax,dx
        mov     di,ax
        add     di,di
        push    0b800h
        pop     es
        ret
;
USEBIOS:
        MOV BL,AH
        MOV AH,0EH
        INT 10H
        RET
;
;; This is a procedure!
;; Have the char in AL, and the color in AH
PutFast:
        CMP     [vmode],3
        JNZ     USEBIOS         ; If it's not a textmode use the BIOS to draw
                                ;  the char.
        mov     si,ax           ; Save the char and color
;
        call    GetXY
        CMP     AL,13
        JNE     @NotCR@
;        call    GetXY           ; Else...
        mov     dl,0
        jmp     MoveXY          ; Move to begining of line and exit
@NotCR@:
        CMP     AL,10
        JNE     @NOTLF@
;        call    GetXY
        CMP     DH,[MaxY]
        JAE     @ScrUpOne@
        inc     dh
        jmp     MoveXY
@NotLF@:
        CMP     AL,7
        JNE     @NotBell@
        mov     ah,0eh
        mov     bh,0
        int     10h     ; Why have my own sound procs? I'll just use BIOS!
        ret
@NotBell@:
        CMP     AL,8
        JNE     @NotBack@
        mov     ah,0Eh
        mov     bh,0
        mov     bl,7
        int     10h     ; Make the code smaller, handling back space takes a
                        ;  fair amount of code. You can always add your own.
        ret
@NotBack@:
;        call    GetXY
        mov     cx,dx
        call    MakeOffset
        mov     es:[di],si
        mov     dx,cx
        CMP     DL,[MaxX]
        JB      @NotAtEndOfLine@
;
        CMP     DH,[MaxY]
        JB      @NotScrTime@
        mov     dl,0
        call    MoveXY
@ScrUpOne@:
#if myscroll
        push ds
        push 0b800h
        pop es
        mov si,160
        xor di,di
        mov al,[MaxY]
        push es
        pop ds
        xor ah,ah
        push ax
#if dwordscroll
        mov cx,40
#else
        mov cx,80
#endif
        mul cx
        push ax
        xchg cx,ax
        rep
#if dwordscroll
        db 66h
#endif
        movsw

        pop di
        pop ax
#if dwordscroll
        shl di,2
#else
        add di,di
#endif
        mov ax,0720h
#if dwordscroll
        db 66h
        rol ax,16
        mov cx,160/4
        mov ax,0720h
#else
        mov cx,160/2
#endif
        rep
#if dwordscroll
        db 66h
#endif
        stosw

        pop ds
        ret
#else
        mov     ax,si
        mov     bh,ah
        mov     ax,0601H
        xor     cx,cx
        mov     dx,w [MaxX]
        int     10h
        ret
#endif
@NotScrTime@:
        mov     dl,0
        inc     dh
        jmp     MoveXY
@NotAtEndOfLine@:
        inc     dl
        jmp     MoveXY
;
; End of the proc
;
#if useansi
;
; ---------------------------------------------------------------------------
; ATOI - convert the string SI points to a number in AX.
; Call with SI pointing to the start of the string, it must be a ASCIIZ
;  string. It returns with the number in BX
; It saves all regs.
;
ATOI:
        push    dx
        push    bx
        push    si
;
        xor     ax,ax
        xor     bx,bx
L1:
        mov     bl,[si]         ; Get the next charater
        sub     bl,"0"
        cmp     bl,"9" - "0"    ; See if we are still in a number
                                ; Note, I subed it by "0", now when we cmp it
                                ;  to "9" - "0" we can see if it's below "0"
                                ;  or higher then it.
        ja      short >L2
        mov     dx,ax
        shl     dx,3
        add     ax,ax
        add     ax,dx           ; Multiply the number by 10 using shifts
        add     ax,bx           ; Add to the number
        inc     si
        jmp     L1
L2:
;
        pop     si
        pop     bx
        pop     dx
        ret
ATOI    endp
;
; Sets the current colour.
;
; ESC[Ps;...;Psm
;
SetColor:
  MOV CX,[NUMPTR]
  MOV SI,OFFSET NUMS
  SUB CX,SI
  JZ RET
  MOV DI,COLORTABLE
  XOR BX,BX
  MOV DL,[COLOR]
;
ColorLoop:
  LODSB
;
  OR AL,AL
  JNZ >L1
  MOV DL,7
  JMP >L2
L1:
  CMP AL,1
  JNZ >L1
  OR DL,08H        ; Colour command 1 is Bold On, bit 3
  JMP >L2
L1:
  CMP AL,5
  JNZ >L1
  OR DL,080H       ; Colour command 5 is Blink On, bit 7
  JMP >L2
L1:
  SUB AL,30             ; See the note under ATOI, same thing.
  MOV BL,AL
  CMP AL,7
  JA >L1
  MOV AL,[DI+BX]        ; Get the right value from the lookup table
  AND DL,0F8H      ; We must clear out the old forground colour before
                        ;  OR in the new one.
  OR DL,AL
  JMP >L2
;
L1:
  SUB AL,10
  CMP AL,7
  JA >L2
  MOV AL,[DI+BX]
  AND DL,08Fh
  OR DL,AL
;
L2:
;
  LOOP ColorLoop
;
  MOV [COLOR],DL
;
  RET
;
; This is used to build up the string for a number.
; I think this is really bad code right here...
; I hope to update it and put it on the web site.
;
HandleNumber:
  MOV BX,[STRPTR]
  CMP AL,'0'
  JB >L1
  CMP AL,'9'
  JA >L1
  MOV [BX],AL
  INC [STRPTR]
  RET
L1:
  PUSH AX
  MOV BYTE [BX],0
  MOV SI,OFFSET STRING
  CALL ATOI
  MOV [STRPTR],SI
;
  MOV BX,[NUMPTR]
  MOV [BX],AL
  INC [NUMPTR]
;
  POP AX
  CMP AL,';'
  JZ RET
;  CMP AL,'?'
;  JZ ENDANSI
;
;  MOV [Current],HandleCommand
  JMP HandleCommand
;
  RET
;
;
Started:
  CMP AL,'0'
  JB HandleCommand
  CMP AL,'9'
  JA HandleCommand
;
  MOV BX,[STRPTR]
  MOV [BX],AL
  INC [STRPTR]
  MOV [Current],HandleNumber
  RET
;
;
ENDANSI:
  MOV [Current],SeeIfBegin
  MOV [NUMPTR],OFFSET NUMS
  RET
;
; ANSI command CursorDown
; Note: The ANSI texts that I have read said the it moves the cursor down
; the number of lines specified, but all of the ANSIs I some times use it
; with no number. In that case you just move it up one.
;
; ESC[PnB
;
MoveDown:
  CALL GETXY
  CMP DH,[MaxY]
  JE RET
;
  CMP [NUMPTR],OFFSET NUMS
  JZ >L1
;
  ADD DH,[NUMS]
  CMP DH,[MaxY]
  JNA >L2
  MOV DH,[MaxY]
  JMP >L2
L1:
  INC DH
L2:
  JMP MOVEXY
;
; Save the cursor postion.
;
SavePos:
  CALL GETXY
  MOV W [OldX],DX
; Here I am making SavePos slower by about 70 clocks...
; But, I save one byte! But, since the ESC[s is used for delays commonly...
;
; Rstores the cursor postion.
;
RestorePos:
  MOV DX,W [OldX]
  JMP MOVEXY
;
; Clears the screen, and homes the cursor (0,0).
;
CLS:
  PUSH 0B800H
  POP ES
  XOR DI,DI
  XOR CX,CX
  MOV CL,[MAXY]
  MOV AX,80
  MUL CX
  MOV CX,AX
  MOV AX,0720h
  REP STOSW
  XOR DX,DX
  JMP MOVEXY
;
; As you may see, I have put the procedures on both sides of this one.
; That is so I have as many short jumps as I can.
;
HandleCommand:
  PUSH ENDANSI
;
  CMP AL,'m'
  IF Z JMP SetColor
;
  CMP AL,'A'
  JZ MoveUp
;
  CMP AL,'B'
  JZ MoveDown
;
  CMP AL,'C'
  JZ MoveRight
;
  CMP AL,'D'
  JZ MoveLeft
;
  CMP AL,'s'
  JZ SavePos
  CMP AL,'u'
  JZ RestorePos
;
  CMP AL,'K'
  JNZ short Over123
  JMP DeleteLine
Over123:
;
  CMP AL,'H'
  JZ CursorPos
;
  CMP AL,'f'
  JZ CursorPos
;
  CMP AL,'J'
  JZ CLS
;
  CMP AL,'?'
  JZ QReset
;
;  CMP AL,'h'
;  JZ RET
;
  RET
;
;
QReset:
  POP AX
  MOV [Current],Started
  RET
;
; Move the cursor up. See the note for MoveDown.
; ESC[PnA
;
MoveUp:
  CALL GETXY
  OR DH,DH
  JZ RET
;
  CMP [NUMPTR],OFFSET NUMS
  JZ >L1
  SUB DH,[NUMS]
  JNC >L2
  XOR DH,DH
  JMP >L2
L1:
  DEC DH
L2:
  JMP MOVEXY
;
; Moves the cursor right, see note for MoveDown.
; ESC[PnC
;
MoveRight:
  CALL GETXY
  CMP DL,[MaxX]
  JZ RET
;
  CMP [NUMPTR],OFFSET NUMS
  JZ >L1
  ADD DL,[NUMS]
  CMP DL,[MaxX]
  JNA >L2
  MOV DL,[MaxX]
L1:
  INC DX
L2:
  JMP MOVEXY
;
; Duh, see note for MoveDown
; ESC[PnD
;
MoveLeft:
  CALL GETXY
  OR DL,DL
  JZ RET
;
  CMP [NUMPTR],OFFSET NUMS
  JZ >L1
  SUB DL,[NUMS]
  JNC >L2
  XOR DL,DL
L1:
  DEC DX                ; This should only change DL (I hope)
L2:
  JMP MOVEXY
;
; Sets the cursor postion.
;
; ESC[PL;PcH
;
CursorPos:
  MOV BX,[NUMPTR]
  MOV CX,BX
  XOR DX,DX
  SUB CX,OFFSET NUMS
  JZ >L1
  MOV DX,W [NUMS]
  DEC DX
  XCHG DL,DH
  DEC DX
  MOV [NUMPTR],OFFSET NUMS
L1:
  JMP MOVEXY
;
;
DeleteLine:
  CALL GETXY
  PUSH DX
  CALL MAKEOFFSET
  POP DX
  MOV AX,0720H
  XOR CX,CX
  MOV CL,[MaxX]
  SUB CL,DL
  REP STOSW
  RET
;
;
;
CheckBracket:
  CMP AL,'['
  JZ  >L1
  MOV [Current],SeeIfBegin
  RET
L1:
  MOV [Current],Started
  RET
;
; This is the default place to call
; We are not in a ESC sequnce right now.
; So we check if the char is the ESC char, if so, next time around it will
;  call the beging procedure for ANSI
; If not we just display the char.
;
SeeifBegin:
  CMP AL,27
  JZ  >L1
  MOV AH,[COLOR]
  JMP PutFast           ; Note, we jump not call to the char draw
                        ;  We don't need to change Current, so why waste a
                        ;  RET?
;
L1:
;
  MOV [Current],CheckBracket
;
  RET
;
;
;
#endif
;
; First we save all of the regs
; Then we call the current procedure.
;
NEWINT:
  STI
  PUSH AX,BX,CX,DX,DI,SI
  PUSH ES,DS
;
  PUSH CS
  POP DS
;
  PUSH 040H
  POP ES
  MOV BL,ES:[84H]
  MOV [MaxY],BL         ; Get the current maxY vaule from a BIOS memory
                        ; location.
  MOV BL,ES:[49H]
  MOV [vmode],BL
;
#if useansi
  CALL [Current]
#else
  MOV  AH,[COLOR]
  CALL PUTFAST
#endif
EXITINT:
  POP DS,ES
  POP SI,DI,DX,CX,BX,AX
#IF debug
  RET                   ; Return
#ELSE
  IRET
#ENDIF
ENDOFINT:
;
; Disposable Data
;
HelpMSG         DB      'Just run with no argments to install it.',13,10
                db      'Run with just "u" to un-install it.',13,10,'$'
Uninstallmsg    db      'Uninstalled.',13,10,'$'
Installmsg      db      13,10
                db  'Fast DOS TTY/ANSI by Skynxnex [LaC] Installed.',13,10,'$'
Alreadymsg      db      'I''m already installed!',13,10,'$'
OkUninstall     db      0

#IF debug
TestStr         db      'f',10,'How are you?',0
#ENDIF

START:
#IF debug
  MOV   SI,OFFSET TestStr
L1:
  LODSB
  or al,al
  JZ RET
  pushf
  CALL  NEWINT
  popf
  JMP L1
L2:
  MOV AX,04C00H
  INT 21H
  RET
#ENDIF

  MOV   AX,(035H SHL 8) OR INT_NUM
  INT   21H                     ; Get the interrupt vector.
;
  CALL  CK_COMMAND_LINE         ; look on the command line to see what the
                                ;  user wants us to do (uninstall, help)
;
  MOV   DI,OFFSET SIGNATURE
  MOV   SI,DI
  MOV   CX,SIGLEN
  REPE  CMPSB                   ; ES = the segment of interrupt vector 29h.
  OR    CX,CX                   ; If CX <> 0, then it's not installed.
  JNZ   >L1
;
  CMP   [OKUninstall],1
  JZ    UNINSTALL               ; If so, go uninstall it.
  PUTS  ALREADYMsg
  JMP   EXIT
L1:
;
  MOV   OLD_INT_29[0],BX
  MOV   OLD_INT_29[2],ES        ; Save the old interrupt vector
;
  MOV   AX,(025H SHL 8) OR INT_NUM
  MOV   DX,OFFSET NEWINT
  INT   21H                     ; Set the int vector
;
  MOV   AX,DS:[2CH]            ; Get the local environment segment
  MOV   ES,AX
  MOV   AH,49H
  INT   21H                    ; Free up the memory
;
  PUTS INSTALLMSG
;
  MOV   DX,ENDOFINT            ; Get the end of the int
  SHR   DX,4                   ; Shift rigth by 4 (div 16) to get para's
  INC   DX                     ; Round up
  MOV   AX,03100H
  INT   21H                    ; The TSR function
;
UNINSTALL:
  PUSH  DS
  PUSH  ES
  MOV   DX,ES:OLD_INT_29[0]
  MOV   DS,ES:OLD_INT_29[2]
  MOV   AX,(025H SHL 8) OR INT_NUM
  INT   21H                    ; Set the int vector back to the old one.
  POP   ES
  POP   DS
;
  MOV   AX,ES
  MOV   ES,AX
  MOV   AH,049H
  INT   021H                   ; Free the memory.

  MOV   DX,OFFSET UNINSTALLMSG
  CALL  PUT_STRING

EXIT:
  MOV   AX,4C00H
  INT   21H

CK_COMMAND_LINE:
  MOV   SI,80H           ; point to the PSP command-tail
  LODSB                  ; get the length of the command tail
  CBW                    ; extend length AL into AX
  OR    AX,AX            ; If no command tail,
  JZ    RET              ;   then exit
  XCHG  CX,AX            ; Put the length of the command tail in CX
L2:
  LODSB                  ; fetch a byte from the command tail
  CMP   AL,'U'           ; if it's one of the uninstall chars,
  JNZ   >L1
  MOV   [OKUnInstall],1  ;   set the flag to true
  JMP   RET
L1:
  CMP   AL,'u'
  JNZ   >L1
  MOV   [OKUnInstall],1  ;    set the flag to true
  JMP   RET
L1:
  CMP   AL,' '
  IF A JMP USAGE
L3:
;
  LOOP  L2
;
  RET

USAGE:
  PUTS  HELPMSG
  JMP   EXIT

;
; Displays a string to stdout.
; Call with DS:[DX] pointing to the string.
;
PUT_STRING:
  PUSH    AX
  MOV     AH,9
  INT     21H
  POP     AX
  RET
