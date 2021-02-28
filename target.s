;these define the location of each variable in the drone_Info struct
%define DRONE_ID 0
%define X 4
%define Y 12
%define ANGLE 20
%define SPEED 28
%define DESTROYED_COUNTER 36
%define ELIMINATED 40
%define DRONE_INFO_STRUCT_SIZE 41


RNG_ROTATION equ 16
MAXRANDOM equ 65535

section .rodata
    boardLimit: dd 100

section .data
    global TARGET_ANSWER
    extern DRONE_ARRAY
	extern CURRENT_DRONE
	extern co_index
	extern CORS
    extern targetDistance
    extern seed
    extern co_index
	extern CORS
    TARGET_ANSWER: db 0
    targetX: dq 0.0
	targetY: dq 0.0
    var1: dd 0
	var2: dd 0
	


section text.
    global target_func
    extern generate_random
    extern resume
    extern printf

    %macro transfer_ctrl 1
            push ecx
            mov ecx,%1
            mov ebx, dword [CORS]
            shl ecx,3
            add ebx,ecx
            pop ecx
            call resume
    %endmacro

    %macro get_drone_info 0
		mov edi,dword [DRONE_ARRAY]  ;ptr to array
		mov esi,dword [CURRENT_DRONE]   ;drone index
		lea edi, [edi+4*esi]  ;ptr to array+drone_index
		mov edi, dword [edi] ;ptr to drone_info
	%endmacro

    generate_target:	;puts new values in targetX and targetY									
		push ebp
        mov ebp,esp
        pushad

		call generate_random
		xor eax, eax
		mov ax, word [seed]
		
		mov dword [var1], eax
		mov dword [var2], MAXRANDOM
		
		finit
		fild dword [var1]
		fidiv dword [var2]
		fimul dword [boardLimit]
		fstp qword [targetX]
		
		call generate_random
		xor eax, eax
		mov ax, word [seed]
		
		mov dword [var1], eax
		
		finit
		fild dword [var1]
		fidiv dword [var2]
		fimul dword [boardLimit]
		fst qword [targetY]
			
		popad
        mov esp,ebp
        pop ebp
        ret



    target_func:
        call generate_target
        transfer_ctrl dword [co_index]

        .loop:
            get_drone_info
            
            mov byte [TARGET_ANSWER], 0
            finit 									;(x1-x2)*(x1-x2)
		    fld qword [edi+X]
		    fsub qword [targetX]
		    fld qword [edi+X]
		    fsub qword [targetX]
		    fmul
		
            fld qword [edi+Y]						;(y1-y2)*(y1-y2)
            fsub qword [targetY]
            fld qword [edi+Y]
            fsub qword [targetY]
            fmul
            fadd
            fsqrt
            
            fcom qword [targetDistance]	;check if the drone is in the range of the target
            fstsw ax									;copy the status word to the AX register
            sahf											;copy the condition bits in the CPUs flag register
            ja .continue
            mov byte [TARGET_ANSWER], 1
            call generate_target
            .continue:
            transfer_ctrl dword [CURRENT_DRONE]
            jmp .loop
            
