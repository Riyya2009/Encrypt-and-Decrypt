;
;This program will test out the functions library to show the user of number formatted output
;

;
;Include our external functions library functions
%include "./functions64.inc"

SECTION .data

	openPrompt	db	"Welcome to my Program", 0h
	closePrompt	db	"Program ending, have a nice day", 0h
	enterKey	db	"Enter encryption key: ", 0h

	lessArg1	db	"Error! NO arguments entered!" , 0h
	moreArgs1	db	"Error! Too many arguments entered!", 0h
	outputError1 db "Error! Unable to open the output file correctly!", 0h
	fileError1 	db "Error! Unable to open the source file correctly!", 0h
	destFileError1 db "Unable to close the destination file correctly (END)!", 0h
	sourceFileError1 db "Unable to close the source file correctly (END)!", 0h
	userMsg		db	"Source file is being copied to the destination file", 0h
	bytesRead1	db	"Total bytes read: ", 0h
	memError 	db	"Memory unsuccessfully dynamically allocated", 0h
	entryError	db	"NO encryption key entered", 0h
	
SECTION .bss
	bytesRead	resq	1					;total bytes read
	keyLength 	resq 	1					;length of encryption key
	sourceFile	resq	1					;source file adress storage
	destFile	resq	1

	sourceHandle resq	1					;source file handle
	destHandle 	resq	1					;destination file handle
	
	encryptKey	resb	255					;store the encrypt key
			.LENGTHOF equ ($-encryptKey)

	currentMem	resq	1					;current mememory of the prg

SECTION     .text
	global      _start

_start:
	nop
	
    push	openPrompt
    call	PrintString
    call	Printendl
    
    mov rcx, [rsp]				;move our num of  arguments to rcx
    cmp rcx, 2					;check number of arguments (less arguments)
    jl lessArgs
    cmp rcx, 3					;check if argumetns are more than 3
    jg manyArgs
    jmp cont
    
    lessArgs:					;no arguments entered 
		push lessArg1
		call PrintString
		call Printendl
		jmp end
		
	 manyArgs:					;more arguments entered than needed
		push moreArgs1
		call PrintString
		call Printendl
		jmp end
		
	;1) Open input file
    ;[rsp+_8] main
    ;[rsp + 16] source file arg
    ;[rsp+ 24] dest file arg
    cont:    
    mov rax, 2h					;open the input file
    mov rdi, [rsp+16]			;pass the source file argument
    mov rsi, 0h					;input file
    mov rdx, 0h				
    syscall						;poke the kernel
    mov [sourceHandle], rax		;save the file handle from rax
    
    cmp rax, 0h					;check if file exists
    jl fileError
    jmp cont2
    
    fileError:					;unable to find the source file, exit the prg
		push fileError1
		call PrintString
		call Printendl
		jmp end
		
	cont2:		
		;2) open the output file
		mov rax, 85						;output file
		mov rdi, [rsp+24]				;dest file arg
		mov rsi, 777o					;read/write/execute
		;mov rdx, 0h
		syscall							;poke the kernel
		
		;check if the output file is opened correctly
		cmp rax, 0
		jl outputError
		mov [destHandle], rax
		jmp cont3
	
	outputError:						;unable to open the output file correctly
		push outputError1
		call PrintString
		call Printendl
		jmp end
	
	cont3:
		;let the user know that the source file is being copied to the destination file
		push userMsg
		call PrintString
		call Printendl
		
		;5) Get users encryption key
		push enterKey
		call PrintString
		push encryptKey					;store the encryptKey adress
		push encryptKey.LENGTHOF		;number of bytes to write
		call	ReadText				;rax contains num of elements in teh encryption key
		dec rax							;remove space being accounted
		
		cmp rax, 0						;check if user entered anything
		je nothingEntered
		jmp cont4
		
		nothingEntered:
			call entryError
			call PrintString
			call Printendl
			jmp end
			
		cont4:					
		mov [keyLength], rax			;length of encryption key moved to variable
		
		;3) Dynamic allocation of 0fffffh bytes to the memory
		mov rax, 0ch					;sys brk command
		mov rdi, 0						;get the current memory adress
		syscall
		mov [currentMem], rax			;store the current memory adress in currentMem
		
		mov rdi, [currentMem]
		add rdi, 0ffffh					;add 0fffh to rax
		;mov rdi, rax
		mov rax, 0ch					;sys_brk command
		syscall							;poke the kernel 
		
		cmp rax, QWORD [currentMem]		;cmp dynamic mem with the start of the memory
		je memoryError
		jmp next3
		
		memoryError:					;check if rax equal to the currentMem
			call memError
			call PrintString
			call Printendl
			jmp closeDest
			
		next3:
		;read the input file
		read:
			mov rax, 0	
			mov r12, 0								;clear out the registers

			mov rsi, [currentMem]					;move the adress of file buffer into rsi
			mov rdx, 0ffffh							;save the file handle from rax.LENGTHOF	;move the size of the buffer
			mov rdi, [sourceHandle]					;move the source handle to rdi
			syscall

			;rax contains the number of bytes to be read
			mov r12, rax							;store the number of bytes it read into r12 to be used later
			add [bytesRead], r12					;add it to the tot bytes read
			cmp rax, 0								;is rax < 0? if yes, error
			jl 	next								;jmps to displaying total bytes read
			
		;encryptme argumnets
		;1st: adress of the allocated mem
		;2nd: length of the allocated meme
		;3rd: address of the encryption key
		;4th: length of encryption key
		encrypt2:
			push QWORD[currentMem]
			push r12
			push encryptKey
			push QWORD [keyLength]
			call EncryptMe
		
		;6) Write the encrypted data to the dest file
		writeDest:
			mov rax, 1								;write
			mov rdi, [destHandle]					;file handle
			mov rsi, [currentMem]					;dest file adress
			;mov rbx, fileBuffer 
			mov rdx, r12							;number of bytes intitally read from the source file
			syscall
			
			cmp r12, 0ffffh							;cmpare r12 with the dynamic mem
			jl next 
			loop  read								;loop again from the reading of the file
		
		
		next:										;print total bytes written to teh dest file
		push bytesRead1
		call PrintString
		push QWORD [bytesRead]						;total bytes read
		call Print64bitNumDecimal
		call Printendl

		;clear dynamic mem
		mov rax, 0ch
		mov rdi, [currentMem]
		syscall
		
		;7) close the files
		mov rax, 3h									;close file
		mov rdi, [sourceHandle]						;which file? source.txt
		syscall
		cmp rax, 0h									;check if the source file closed correctly
		jl sourceFileError							;file error
		jmp closeDest
		
		sourceFileError:
			push sourceFileError1
			call PrintString
			call Printendl

		closeDest:									;close the destination file
			mov rax, 3h
			mov rdi, [destHandle]
			syscall
			cmp rax, 0h								;check if the source file closed correctly
			jl destFileError
			jmp end
			
		destFileError:								;unable to close it correctly
			push destFileError1
			call PrintString
			call Printendl
	
	end:											;end of the prg
	nop
    push	closePrompt								;The prompt address - argument #1
    call  	PrintString
    call  	Printendl
    nop
;
;Setup the registers for exit and poke the kernel
;Exit: 
Exit:
	mov		rax, 60					;60 = system exit
	mov		rdi, 0					;0 = return code
	syscall							;Poke the kernel

EncryptMe:
	;create stack frame
	push rbp
	mov rbp, rsp
	
	;push all registers to save their values
	push rbx
	push rcx
	push rsi
	push rdx
	;push r10
	
	;clear out all teh regsiters 
	mov r8, 0h
	mov r9, 0h
	mov r10, 0h
	mov r11, 0h
	mov r13, 0h							;index register
	mov rbx, 0h
	mov rcx, 0h							;loop counter
	mov rdx, 0h
	mov rax, 0h
	
	mov r8, QWORD [rbp+40]				; adress of allocated meme
	mov rcx, QWORD [rbp +32]			;allocated mem length
	mov rdx, QWORD [rbp + 24]			;encryption key
	mov r11,  QWORD [rbp + 16]			;encryption key length 
	;mov rsi, [fileBuffer]				;pointing to number of bytes read frim source file
	encryption:
		mov bl, BYTE [r8 + r13]			;move the byte from the allocated mem + index register
		mov al, BYTE [rdx + r10]		;xor byte by byte through teh encryption key which is the third argument
		xor al, bl
		mov BYTE [r8 + r13], al			;reqrite the allocatetd mem w encrypted byte
		add r13, 1
		add r10, 1
		cmp r10, r11					; is the index register = encryption key length?
		je 	sameIndex
		cont5:
	loop encryption
	jmp next2
	
	sameIndex:
		mov r10, 0h					;reset the index counter
		jmp cont5
	
	next2:
	;clear the arguments from teh stack
	mov QWORD [rbp + 40 ], 0
	mov QWORD [rbp + 32], 0
	mov QWORD [rbp + 24 ], 0
	mov QWORD [rbp + 16 ], 0
	
	;restore the registers
	pop rdx
	pop	rsi 
	pop rcx
	pop rbx
	
	;destroy stack frame
	mov rsp, rbp
	pop rbp
	
	ret 32
