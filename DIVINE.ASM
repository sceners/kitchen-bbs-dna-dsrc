comment *

(c) 1997 CopyRite by dawn of a new age (d.n.a.)
EXCLUDING the original plasma generator, colorrange and amd player

*

music=1       ;want adlib to be initialized?
locals

code            segment use16
                assume  cs:code,ds:code
                org     100h
.486
main:
                fninit
                mov     di,offset seg1
                mov     cx,5
                push    es
                pop     ax
getmem:         add     ah,10h
                stosw
                loop    getmem

                mov     di,offset pal
                mov     cx,256*3
                xor     al,al
                rep     stosb                   ;clear the palette for addmix

;inits the sine and cosine table

                fild    [val256]
                mov     si,offset sin_table
                mov     cx,512+128              ;so full sine plus rest of cos
cs1:
                fild    [temp]                  ;get angle
                fdiv    st,st(1)
                fldpi
                fmulp   st(1),st                ;converted to radians
                fsin
                fild    [sin_amplitude]         ;mul with amplitude
                fmulp   st(1),st                ;float -> fixed point
                fistp   word ptr [si]           ;store fixed point value
                inc     si
                inc     si
                inc     [temp]                  ;advance angle
                dec     cx
                jnz     cs1

                mov     es,cs:[seg3]
                call    plasma_init     ;create the height field

                xor     si,si
shape_height:
                mov     al,[si]         ;get plasma value
                inc     ax              ;round
                shr     al,1            ;limit to 0..127
                mov     [si],al         ;store
                inc     si              ;and advance pointer
                jnz     shape_height

                push    ds              ;fs=ds for later background calc
                pop     fs

                mov     es,cs:[seg4]
                call    plasma_init     ;create the texture plasma

                xor     si,si
shape_texture:                          ;limit the texture to 64..127
                mov     al,[si]
                shr     al,2
                add     al,64           ;offset because of palette location
                mov     [si],al
                inc     si
                jnz     shape_texture

                push    cs
                pop     ds

                mov     es,[seg5]       ;generate the background
                xor     di,di

                mov     cx,-100         ;starting y
ct2:
                mov     dx,-160         ;starting x
ct1:
                mov     [temp],cx
                fild    [temp]
                fld     [y_adjust]
                fmulp   st(1),st        ;adjust to mode13 perspective
                mov     [temp],dx
                fild    [temp]

                fld     st(1)
                fmul    st,st(2)
                fld     st(1)
                fmul    st,st(2)
                faddp   st(1),st
                fsqrt                   ;calculate the distance to center
                fistp   [temp]          ;=the radius
                mov     bh,byte ptr [temp]

                fpatan
                fldpi
                fdivp   st(1),st
                mov     [temp],512
                fild    [temp]
                fmulp   st(1),st
                fchs
                fistp   [temp]          ;calculate the angle via arctan
                mov     bl,byte ptr [temp]

                add     bl,bh           ;xnew=x+2*y to achive the spiral
                add     bl,bh

                mov     al,fs:[bx]      ;read plasma value
                cmp     al,64           ;convert it from 128 to 64 colors
                jb      ct3
                sub     al,127
                neg     al
ct3:
                mov     es:[di],al      ;store in bg

                inc     di

                inc     dx
                cmp     dx,160          ;one row done?
                jl      ct1

                inc     cx
                cmp     cx,100          ;all done?
                jl      ct2

                mov     es,[seg2]       ;initialize the projection table
                xor     di,di
                mov     dx,128          ;number of possible height values
                mov     [y],64          ;starting height <>0 to yield more volume
ct4:
                fninit
                fild    [y]             ;the radius of the current 256 line
                fmul    [weird]         ;scales the line
                mov     cx,256          ;number of angles
                mov     [x],0           ;starting angle
ct5:
                fild    [x]             ;the angle of the current 256 line
                fldpi
                fmulp   st(1),st
                fild    [val256]
                fdivp   st(1),st        ;converted to radians
                fsin                    ;parallel project with sine
                fmul    st,st(1)
                fistp   [temp]
                mov     al,byte ptr [temp]
                inc     al              ;needed so 0ø line will still be drawn
                stosb                   ;save the projection of y
                add     di,127          ;advance to next angle in the table
                inc     [x]
                loop    ct5

                add     di,32768        ;skip the unused rest of the table

                inc     [y]             ;new plasma height to project
                inc     di              ;next "horizontal" slot in table
                dec     dx
                jnz     ct4

                mov     ax,13h
                int     10h

                mov     di,offset pal

                mov     cl,32
                mov     bx,1501h
                mov     dx,0000h        ;black to gray
                call    colorrange

                mov     cl,32
                mov     bx,19ffh
                mov     dx,0020h
                call    colorrange
                sub     di,32*3
                mov     cl,32
                mov     bx,2601h
                mov     dx,0020h        ;gray to green
                call    colorrange

                mov     cl,32
                mov     bx,05feh
                mov     dx,3f3fh        ;yields more white clouds
                call    colorrange

                mov     cl,32
                mov     bx,0502h
                mov     dx,3f00h
                call    colorrange      ;yields white clouds

                mov     si,offset pal
                call    writepal        ;out the palette

                mov     cl,3            ;starting transparency level
                mov     di,offset transpar_pal
                mov     dl,20h          ;set the color of the font
                xor     bx,bx
ct7:
                mov     si,offset pal   ;original palette
ct6:
                mov     al,dl           ;load font color component

                mov     dl,bh
                mov     bh,bl
                mov     bl,al           ;rotate components

                mul     cl              ;mul with fraction
                xchg    ax,bp
                lodsb                   ;load red palette component
                not     cl              ;1-fraction
                mul     cl
                not     cl
                add     ax,bp           ;add both fractions
                add     ax,127          ;round
                mov     al,ah           ;fixed->int
                stosb                   ;store mix

                cmp     si,offset pal+128*3
                jnz     ct6

                add     cl,3            ;next 128-color-segment
                cmp     cl,192
                jna     ct7

                mov     ax,1130h
                mov     bh,03
                int     10h
                mov     [fontofs],bp
                mov     [fontseg],es     ;save pointer to 8x8 system font

                push    40h
                pop     es
                mov     eax,es:[6ch]
                mov     [randseed],eax  ;store timer dependent rand seed

if music eq 1
                push    ds
                pop     es
     	        mov     si,offset alloyrun
	        mov     di,offset WorkBuffer
	        xor     al,al
	        call    _InitAdlib      ;init conqueror's adlib player
endif

                mov     fs,[seg2]       ;projection table
                mov     gs,[seg3]       ;height data
                mov     word ptr [temp],0

main_loop:
                push    ds
                mov     es,[seg1]       
                mov     ds,[seg5]
                xor     si,si
                xor     di,di
                mov     cx,32768/2
                rep     movsd           ;write background page
                pop     ds

                mov     es,[seg4]
                mov     al,byte ptr [val256]
                or      al,al           ;voxel enabled?
                jnz     no_voxel        
                call    voxel_texture   ;sky texture
no_voxel:
                mov     es,[seg1]       ;where to mix the font into
                call    transparency    ;do transparency effect
                call    draw_screen     ;write ds to video screen

                push    cs
                pop     ds

                add     [texture_shift],2       ;moves texture upwards
                add     [rotor],8               ;global rotation of voxel

                mov     ah,1
                int     16h                     ;check for key
                jz      main_loop
                mov     ax,0
                int     16h                     ;read the key

                xor     bx,bx                   ;init checksum vars
                xor     dx,dx
                mov     si,offset code_string
                mov     [si+17],ah              ;store new key
                mov     cl,17
get_code:
                mov     bl,[si+1]               ;update key queue
                mov     [si],bl
                add     dx,dx                   ;with this, sequence will matter
                add     dx,bx                   ;do some sort of a check sum
                inc     si
                dec     cl
                jnz     get_code

                cmp     dx,0f2a6h               ;results in correct string?
                jne     main_loop

                not     byte ptr [val256]       ;toggle the voxel
                mov     [si-1],bh               ;and trash the queue
                jmp     main_loop

loaderror:
                push    cs
                pop     ds

if music eq 1
	        call    _StopAdlib              ;halt amd
endif

                mov     ax,3
                int     10h

                mov     ah,2
                xor     bh,bh
                mov     dx,1700h
                int     10h                     ;position the cursor

                push    0b800h
                pop     es
                xor     di,di
                mov     si,offset end_ansi
                mov     cx,80*24
                rep     movsw                   ;display the end ansi

                int     20h

;****************************************************************************
; voxels the texture to seg1
;****************************************************************************
; the height map is scanned top to bottom for 200 lines in 2 runs. for each
; horizontal line 256 pixels are read from the height map and the
; value(=height) is used along with the current angle (equale to the x pos
; in the height map) to look up a value as 64+0.75*height*sin(pi*angle/256)
; thus at max 160 or half the screen. this value is then compared to the
; last drawn length and only if visible the difference is drawn to screen.
; updating the max length allows the slime to be drawn front to back while
; no pixel is ever drawn without being visible. the value of the pixel comes
; from the texture and ist determined by the position in the bitmap and
; a distance in y direction which allows the movement of the texture on
; the slime upwards. the motion is done by a sine dependent offset to each
; scanline stored in shear_table which is stored as deltas for speed and
; a global rotator which holds the base spin. turning the slime is done by
; altering the starting value of the frontal pixel. the right side is scanned
; separately to the left though it does only differ in code in the direction
; to move on screen and in the height and texture map.
;****************************************************************************
voxel_texture   proc
                push    ds

                xor     bx,bx
                mov     bl,[rotor]

                mov     bp,[shear]
                add     bp,4*2
                and     bp,1023
                mov     [shear],bp      ;advance slime shear

                mov     si,offset shear_table
                xor     di,di           ;di=last shear=0
                mov     cx,200          ;number of lines to shear
vp3:
                mov     ax,sin_table[bp]
                add     bp,2
                and     bp,1023         ;load sin values in sequence

                sar     ax,6
                mov     dx,ax           ;dx=ax=clipped sine value (signed)

                sub     dx,di           ;determine distance to previous shear
                xchg    ax,di           ;reset previous to current shear

                mov     [si],dl         ;store the DIFFERENCE of shear to last
                inc     si              ;advance
                dec     cx
                jnz     vp3

                mov     di,160          ;top line - middle of screen
                xor     si,si           ;first entry in projection table

                mov     ch,[texture_shift]

                mov     ds,[seg1]       ;paint into vscreen

                push    bx              ;store orginal map position for later

                mov     bp,offset shear_table
@@3:
                xor     ah,ah           ;ah will stay =0
                xor     dx,dx           ;dh=maxline=0, dl=angle counter=256=0
                push    di              ;keep screen offset

                add     bl,[bp]         ;add shear to horizontal position
                inc     bp              ;advance to next entry
                push    bp
@@1:
                mov     al,gs:[bx]      ;load a height
                mov     bp,si           ;bp=base offset in proj table
                add     bh,ch           ;add texture shift
                add     bp,ax           ;add height to index projected height
                mov     al,es:[bx]      ;read texture color
                sub     bh,ch           ;undo the shift of bx
                mov     cl,fs:[bp]      ;read projected height from table
                inc     bl              ;advance in height map
                add     si,128          ;advance proj base to next angle
                sub     cl,dh           ;height<=maxline?
                jbe     short @@2       ;yep - not visible - don't draw

                add     dh,cl           ;dx=new maxline
@@4:
                mov     [di],al         ;store texture color
                inc     di              ;into vscreen
                dec     cl              ;for (height-old maxline) times:
                jnz     short @@4       ;the slice actually visible
@@2:
                dec     dl              ;more angles to go?
                jnz     short @@1

                pop     bp              ;get shear index back
                pop     di              ;get original screen offset

                inc     bh              ;next line in height map

                add     di,320          ;next line on screen
                add     si,32768        ;skip rest of projection table

                cmp     di,160+320*200
                jb      short @@3       ;not done yet

;the code below equals the above only the direction to advance on screen and
;in the height map is -1 ... self modifying code could be used for small size

                mov     di,160          ;again start at top
                xor     si,si
                pop     bx              ;get the height map index back

                mov     bp,offset shear_table
@@3a:
                xor     ah,ah
                xor     dx,dx
                push    di

                add     bl,[bp]
                inc     bp
                push    bp
@@1a:
                mov     al,gs:[bx]
                mov     bp,si
                add     bh,ch
                add     bp,ax
                mov     al,es:[bx]
                sub     bh,ch
                mov     cl,fs:[bp]
                dec     bl                      ;inverse direction
                add     si,128
                sub     cl,dh
                jbe     short @@2a

                add     dh,cl
@@4a:
                mov     [di],al
                dec     di                      ;inverse direction
                dec     cl
                jnz     short @@4a
@@2a:
                dec     dl
                jnz     short @@1a

                pop     bp
                pop     di

                inc     bh

                add     di,320
                add     si,32768

                cmp     di,160+320*200
                jb      short @@3a

                pop     ds
                ret
voxel_texture   endp

;****************************************************************************
; adds the font to seg1
;****************************************************************************
; this routine will create a new text whenever the pal has been faded down to
; max and a fadeup is initiated because the non display interval has elapsed.
; it will read the next 3 strings and decode them using the system font.
; the next 64 draws a new palette (precalced) is written to simulate real-
; time alpha blending. if text_state reaches 0 a display period is initiated.
; upon elapse the direction of palette order is reversed and the palette fades
; down. this cycles. the text_display is written with text_pixels length each
; frame into the bg, shifting the colors of the transparent bg into another
; color range (128..255). it starts at random values calced each time a new
; string is read.
;****************************************************************************
transparency    proc

                mov     cl,[text_state]
                or      cl,cl                   ;need to fade?
                jz      in_display              ;no - font is being displayed

                mov     dword ptr [time],0      ;start time counter

                cmp     [text_pal_ofs],offset transpar_pal-128*3
                ja      no_new_text             ;either fading down or text ok

                push    cs
                pop     es
                mov     di,offset text_display
                mov     cx,320*8*3/2
                xor     ax,ax
                rep     stosw
                mov     cl,[text_state]         ;clear window for new text

                mov     es,[fontseg]

                mov     di,offset text_display

                mov     ch,3                    ;3 lines

                mov     si,[text_pointer]       ;load pointer to string
                cmp     si,offset intro_text_end
                jb      text_pointer_ok         ;text pointer is valid
                mov     si,[text_repeat]
                mov     [text_pointer],si       ;repeat the text
text_pointer_ok:
                mov     bp,[si]                 ;load counter
                add     si,2
                add     di,bp                   ;adjust horizontal offset
@@4:
                mov     bl,[si]                 ;load character
                inc     si
                xor     bh,bh
                or      bl,bl
                jz      create_text             ;terminator?

                mov     dh,8
                shl     bx,3                    ;mul with font size in bytes
                add     bx,[fontofs]            ;es:bx=pointer to font
@@1:
                mov     ah,es:[bx]
                mov     dl,8
@@2:
                rol     ax,1                    ;decode the
                and     al,1                    ;bit compression
                mov     [di],al                 ;transfer 8 horizontal pixels
                inc     di

                dec     dl
                jnz     @@2

                add     di,320-8                ;one row down
                inc     bx                      ;advance 8 bits(=pixels)

                dec     dh
                jnz     @@1

                add     bp,8                    ;add pixels to counter
                add     di,8-320*8              ;reposition display pointer

                jmp     @@4

create_text:
                cmp     bp,[text_pixels]
                jb      @@3
                mov     [text_pixels],bp        ;store the max pixel counter
@@3:
                mov     [text_pointer],si       ;update text pointer

                sub     di,bp
                add     di,320*8                ;move one slot down

                dec     ch
                jnz     text_pointer_ok

                mov     bx,290                  ;init the coordinates
                sub     bx,[text_pixels]        ;for the upper left
                call    rnd                     ;corner so the text
                add     ax,15                   ;won't appear in the
                mov     [x],ax                  ;outer margins
                mov     bx,200-3*8
                call    rnd
                mov     [y],ax
no_new_text:

                cmp     cl,64                   ;starting a pal fade?
                jb      dont_adjust
                mov     ax,[text_pal_diff]
                add     [text_pal_ofs],ax       ;then fix the pal pointer
dont_adjust:

                push    ds
                pop     es

                mov     di,offset pal+128*3
                mov     si,[text_pal_ofs]
                mov     cx,128*3
                rep     movsb                   ;write the palette

                mov     si,offset pal+128*3
                mov     dx,3c8h
                mov     al,128
                out     dx,al
                inc     dx
                mov     cx,128*3
                rep     outsb                   ;output the fading pal

                mov     ax,[text_pal_diff]
                add     [text_pal_ofs],ax       ;advance pal in set direction

                dec     [text_state]            ;change counter
                jnz     trans_pixels            ;not reached end yet
                neg     [text_pal_diff]
                jmp     trans_pixels            ;go transfer pels to vscreen

in_display:                                     ;check time counter of last fade
                mov     bx,100                  ;time to hold display
                cmp     [text_pal_ofs],offset transpar_pal-128*3
                jne     @@5
                mov     bx,20                   ;time to not display next
@@5:
                mov     ax,2[time]
                cmp     ax,bx                   ;check the counter agains value
                jb      dont_kill
                mov     [text_state],64         ;now need to kill or send text
dont_kill:
;transfer the pixels to screen
trans_pixels:
                mov     bp,offset text_display  ;ss:bp=text data
                mov     si,[text_pixels]        ;cx=# of pixels in text
                mov     dx,320
                sub     dx,si                   ;dx=# of pixels of empty space
                mov     di,[y]                  ;calculate position
                imul    di,320
                add     di,[x]
                mov     ds,[seg1]               ;ds:di=pos of upper corner
t2:
                mov     cx,si                   ;load the pixel counter
t1:
                mov     al,[di]                 ;get a pixel from bg
                mov     ah,[bp]                 ;get a font pixel
                add     al,128                  ;premix bg pixel (just in case)
                or      ah,ah
                jz      t3                      ;don't change bg
                mov     [di],al                 ;write mix pixel
t3:
                inc     di                      ;advance
                inc     bp

                dec     cx
                jnz     t1

                add     bp,dx                   ;move to new line
                add     di,dx

                cmp     bp,offset text_display+320*8*3
                jb      t2

                ret
transparency    endp


;****************************************************************************
; will create a plasma in es
;****************************************************************************
; the following routines have been taken from a file which origin and name
; i don't recall. i hacked mars as well and included some of the stuff seen.
; i thank the author of this code though i don't know who it was. i had to
; make the code into procedures though to get the size down to 200 bytes.
; the comments present here are from the original author and i won't change
; around them, cause it's not my code. but you can use any fractal generator
; if it fills es with data.
;****************************************************************************
plasma_init     proc
                xor     di,di
                mov     ax,0ffffh
                mov     cx,32768
                rep     stosw

                push    es
                pop     ds

                xor     bx, bx
                mov     cx, 0100h
                mov     byte ptr ds:[0080h], -2
                mov     byte ptr ds:[8000h], -2
                mov     byte ptr ds:[0000h],  cl
                mov     byte ptr ds:[8080h],  cl

                push    0
                push    256
                call    hell            ;initial call to subdivider
                call    smooth
                ret
plasma_init     endp

Smooth          proc

                xor     si,si
                xor     bx,bx
@Loop:
                mov     al,[bx]
                xor     ah,ah
                add     al,[bx+4]
                adc     ah,0
                add     al,[bx+202h]
                adc     ah,0
                add     al,[bx+0FEFFh]
                adc     ah,0
                shr     ax,2

                mov     es:[bx],al
                add     bx,1
                jnc     @Loop

	        ret
Smooth          endp


hell            proc    pascal pos:word, len:word

                pusha
	        call    random          ;init random

                mov     ax,[pos]
                mov     cx,[len]
                shr     cx,1
                jz      @finished

                xor     bp,bp
                xchg    ax,bx
                mov     ch,cl

                call    hp2

                neg     cl
                call    hp2
                neg     cl

                mov     dx,bp           ;fetch the collected value

	        shr     dx,2              ; divide by 4
                add     bl,cl
                add     bh,cl

	        call    AddRandom
	        mov     [bx],al

                xor     ch,ch
                push    bx                ;centrepoint: br square
                push    cx
	        call    hell

                sub     bl,cl             ;bl square
                push    bx
                push    cx
	        call    hell

                sub     bh,cl             ;tl square
                push    bx
                push    cx
	        call    hell

                add     bl,cl             ;tr square
                push    bx
                push    cx
	        call    hell
@Finished:
                popa
                ret

hell            endp

hell_procs      proc
hp1:
                xor     dh,dh
                add     bp,dx
                cmp     byte ptr [di],0FFh
	        jne     @@1
                add     dl,[bx]
                adc     dh,0
	        shr     dx,1
	        call    AddRandom
	        mov     [di],al
@@1:
                ret
hp2:
	        mov     dl,[bx]
	        add     bl,cl
	        mov     di,bx
	        add     bl,cl

                call    hp1

                mov     dl,[bx]
                add     bh,cl
                mov     di,bx
                add     bh,cl

                call    hp1
                ret

hell_procs      endp


; Input: dx = raw value ch=size of random displacement
; Output al = clipped final value
; Modifies dx,ax

addrandom   proc	near

                push    dx

		call	Random
                sub     ax, 67E8h

                mov     dl,ch
                xor     dh,dh
                shl     dx,3

                imul    dx
                pop     ax

                xor     ah,ah
                add     dl,al
                mov     al,ah
                adc     dh,ah

                js      @CS2   ; If dh <0 use 0
                jz      @CS1	; if dh =0 use dl
				; Else dh >0use 0feh
                mov     dl, 0FEh
  @CS1:
                mov     al, dl
  @CS2:				; Else if dh = 0 use 0
		ret

addrandom	endp

;kills ax,si
Random          proc
                push    dx
                mov     si,offset randseed
                mov     eax,cs:[si]
                mul     dword ptr cs:[si+4]
                inc     eax
                mov     cs:[si],eax
                shr     eax,16
                pop     dx
                ret
random          endp

rnd             proc
                call    random
                mul     bx
                shrd    ax,dx,16
                ret
rnd             endp

;draws ds to video segment
draw_screen     proc
                push    0a000h
                pop     es
                xor     di,di
                xor     si,si
                mov     cx,32768
                rep     movsw

                in      al,60h          ;allow termination via port
                cmp     al,1            ;used in seven - virtually stupid here
                je      loaderror       

                ret
draw_screen     endp

;clears es
clrscr          proc
                xor     di,di
                xor     ax,ax
                mov     cx,32768
                rep     stosw
                ret
clrscr          endp

writepal        proc
                mov     dx,3c8h
                xor     al,al
                out     dx,al
                inc     dx
                mov     cx,256*3
                rep     outsb
                ret
writepal        endp

;****************************************************************************
; will set a colorrange
;****************************************************************************
; this procedure was inspired by lbd (sanction) and originally pasted from
; the code. i had to modify it generally otherwise the beautiful pals seen
; in 'seven' would not have been possible at all. it now uses an additive
; mixing and does allow for keeping colors at a constant level as well as
; incrementing some component(s) and halving other(s). i'm not going to get
; into the guts of it, since its too wheeny a code.
;****************************************************************************

;dh=konstant for non present colors
;dl=starting level
;bl=adder
;bh=color presence bits
;bp=# of triples

Colorrange      proc    near
                push    ds
                pop     es
CROloop:
                mov     ch,3
                mov     ah,bh
CRIloop:
                mov     al,dl

                shr     ah,1
                jc      short CRCarry
                mov     al,dh
                test    ah,1
                jz      CRCarry
                xor     al,al
CRCarry:
                shr     ah,1
                jnc     short CRHalf
                shr     al,1
CRHalf:
                add     es:[di],al
                inc     di
                dec     ch
                jne     short CRIloop

                add     dl,bl

                dec     cl
                jne     short CROloop
                ret
Colorrange      endp

randseed        dd      2349231         ;random seed
                dd      134775813       ;random multiplicator

include         amdobj.asm              ;the player
include         alloyrun.inc            ;the tune

weird           dd      0.75            ;the scale for the plasma values

shear           label   word            ;any initial value just has to be even
sin_amplitude   dw      16384
y_adjust        dd      1.2             ;screen adjust for mode13h
val256          dw      256
temp            dw      0               ;length of text in pixels

include         ansi.inc                ;the end ansi

text_pointer    dw      offset intro_text
text_repeat     dw      offset intro_text
text_pal_ofs    dw      offset transpar_pal-128*3
text_pal_diff   dw      128*3
text_state      db      64

intro_text      label   byte
                dw      12
                db      'THiS WiCKED FiLE',0
                dw      0
                db      'MELDTED THROUGH THE',0
                dw      48
                db      'KiTCHEN',0

                dw      24
                db      '24h ONLiNE WiTH',0
                dw      24
                db      'GOOD OLD 28.800',0
                dw      0
                db      'AND WHiPPiNG FAST 64k',0

                dw      0
                db      'BOARD AND NODES',0
                dw      16
                db      'MASTERED BY',0
                dw      32
                db      'BUTCHER',0

                dw      36
                db      'HELPED iN BY',0
                dw      20
                db      'REMOTE CO-SYSOPS',0
                dw      0
                db      'POSiTiVE PAiN & AXESS',0

                dw      20
                db      'SUPPORTiNG TWO LiNES:',0
                dw      12
                db      '49-30-662-9822 [28.800]',0
                dw      0
                db      '49-30-660-98691 [64k iSDN]',0

                dw      12
                db      'CARRYiNG COPiOUS',0
                dw      12
                db      'ART ORiENTED AND',0
                dw      0
                db      'SCENE RELATED FiLES',0

                dw      0
                db      'WORLD HEADQUARTER',0
                dw      32
                db      'OF DEMONS',0
                dw      16
                db      'EHQ OF STATiC',0

                dw      36
                db      'GHQ OF',0
                dw      0
                db      'AMBUSH, MONO AND',0
                dw      4
                db      'VOYAGER PROJECT',0

                dw      72
                db      'DiSTRO FOR',0
                dw      0
                db      'ADVANCED RHYTHM TECHNOLOGiES',0
                dw      88
                db      'GiLDEN',0

                dw      28
                db      'ZERO.ONE',0
                dw      16
                db      'OUTTA SPACE',0
                dw      0
                db      'SPiRiT OF CRiME',0

                dw      4
                db      'iNFiNiTE',0
                dw      24
                db      'AND',0
                dw      0
                db      'ASTROiDEA',0

                dw      12
                db      'SUPPORT GiVEN TO',0
                dw      0
                db      'THE UNCONSCiOUSNESS',0
                dw      36
                db      'AND APOLLO',0

                dw      28
                db      'CODE: ELiZA/D.N.A.',0
                dw      0
                db      'PLAYER: CONQUEROR/ELYSSiS',0
                dw      24
                db      'MUSiC: VOiD/REALiTY',0

                dw      0
                db      'THE CREATOR WiLL',0
                dw      0
                db      'ENLiGHTEN YOU TO',0
                dw      8
                db      'WHAT iS BEHiND',0
intro_text_end  label   byte

text_pixels     dw      ?               ;# of pixels in text_display per line

rotor           db      ?               ;the global slime rotor
texture_shift   db      ?               ;the texture shifter
x               dw      ?               ;x pos of text
y               dw      ?               ;y pos of text

fontofs         dw      ?               ;for the system font
fontseg         dw      ?

seg1            dw      ?               ;vscreen
seg2            dw      ?               ;projection table
seg3            dw      ?               ;height data
seg4            dw      ?               ;texture
seg5            dw      ?               ;background

code_string     db      18 dup (?)

sin_table       dw      128 dup (?)
cos_table       dw      512 dup (?)

shear_table     db      200 dup (?)

transpar_pal    db      64 dup (128 dup (?,?,?))

text_display    db      320*8*3 dup (?)

pal             db      256*3 dup (?)

code            ends
                end     main