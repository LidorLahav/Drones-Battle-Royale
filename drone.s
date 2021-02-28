
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

section .data
	extern TARGET_ANSWER
    extern DRONE_ARRAY
	extern CURRENT_DRONE
	extern co_index
	extern CORS
	extern target_co_index
	extern seed
	extern targetDistance
    
	max_bound: dd 800
	targetsDestroy: dd 0
	var1: dd 0
	var2: dd 0
	zero: dd 0
	halfCircle: dd 180
	boardLimit: dd 100
	angleLimit: dd 360
	boundSpeed: dd 20
	halfBoundSpeed: dd 10
	boundAngle: dd 120
	halfBoundAngle: dd 60
	
	targetX: dq 0.0
	targetY: dq 0.0


section .bss


section .text
    global drone_func
    extern malloc
    extern free
	extern resume
	extern generate_random
    
	%macro get_drone_info 0
		mov edi,dword [DRONE_ARRAY]  ;ptr to array
		mov esi,dword [CURRENT_DRONE]   ;drone index
		lea edi, [edi+4*esi]  ;ptr to array+drone_index
		mov edi, dword [edi] ;ptr to drone_info
	%endmacro

	%macro transfer_ctrl 1
            push ecx
            mov ecx,%1
            mov ebx, dword [CORS]
            shl ecx,3
            add ebx,ecx
            pop ecx
            call resume
    %endmacro

	%macro start_method 0
        push ebp
        mov ebp,esp
    %endmacro
    
    %macro end_method 0
        mov esp,ebp
        pop ebp
        ret
    %endmacro
	
	move_forward:								;get to a new position and then change the angle and speed
		start_method
		get_drone_info
		;-------------new_position------------
		pushad
		xor eax, eax
		mov dword [var1], 0
		
		;change angle to radians
		finit
		fldpi
		fmul qword [edi+ANGLE]
		fidiv dword [halfCircle]				;s(0) angle in radians to use cos/sin
		
		;find y and check bounds 
		fst st1
		fsin
		fmul qword [edi+SPEED]
		fadd qword [edi+Y]
		
		;check if y is negative
			ficom dword [max_bound]		;x == 800
			fstsw ax									;copy the status word to the AX register
			sahf											;copy the condition bits in the CPUs flag register
			jb .upper_bound						;x < 800
			fabs
			fisub dword [boardLimit]
			fabs
			jmp .check_x_negative
		
		.upper_bound:
			ficom dword [boardLimit]		;y == 100
			fstsw ax									;copy the status word to the AX register
			sahf											;copy the condition bits in the CPUs flag register
			jbe .lower_bound					;y <= 100
			fisub dword [boardLimit]
			jmp .check_x_negative
		
		.lower_bound:
			ficom dword [var1]					;y == 0
			fstsw ax									;copy the status word to the AX register
			sahf											;copy the condition bits in the CPUs flag register
			jae .check_x_negative						;y >= 0
			fiadd dword [boardLimit]
		
		.check_x_negative:
			fstp qword [edi+Y]
			
			;find x and check bounds 
			fcos
			fmul qword [edi+SPEED]
			fadd qword [edi+X]
			
			;check if x is negative
			ficom dword [max_bound]		;x == 800
			fstsw ax									;copy the status word to the AX register
			sahf											;copy the condition bits in the CPUs flag register
			jb .right_bound						;x < 800
			fabs
			fisub dword [boardLimit]
			fabs
			jmp .end_position_checking
			
		.right_bound:
			ficom dword [boardLimit]		;x == 100
			fstsw ax									;copy the status word to the AX register
			sahf											;copy the condition bits in the CPUs flag register
			jbe .left_bound						;x <= 100
			fisub dword [boardLimit]
			
		.left_bound:
			ficom dword [var1]					;x == 0
			fstsw ax									;copy the status word to the AX register
			sahf											;copy the condition bits in the CPUs flag register
			jae .end_position_checking					;x >= 0
			fiadd dword [boardLimit]
		
		.end_position_checking:
		fstp qword [edi+X]
		
		
		popad					;from new_position
		
		;------------generate_bound_angle_and_speed-------------
		
		pushad
		call generate_random
		xor eax, eax
	
		mov ax, word [seed]
		mov dword [var1], eax
		mov dword [var2], MAXRANDOM
		
		finit														;generate angle in the range of [-60, 60] and add it to the original angle
		fild dword [var1]
		fidiv dword [var2]
		fimul dword [boundAngle]
		fisub dword [halfBoundAngle]
		fadd qword [edi+ANGLE]
		
		;check if angle is negative
			ficom dword [max_bound]		;x == 800
			fstsw ax									;copy the status word to the AX register
			sahf											;copy the condition bits in the CPUs flag register
			jb .angle_lower_bound			;x < 800
			fabs
			fisub dword [angleLimit]
			fabs
			jmp .check_speed_negative
		
		.angle_lower_bound:
			mov dword [var1], 0
			ficom dword [var1]					;angle == 0
			fstsw ax									;copy the status word to the AX register
			sahf											;copy the condition bits in the CPUs flag register
			jae .angle_upper_bound			;angle >= 0
			fiadd dword [angleLimit]
			jmp .check_speed_negative
		
		.angle_upper_bound:
			ficom dword [angleLimit]		;angle == 360
			fstsw ax									;copy the status word to the AX register
			sahf											;copy the condition bits in the CPUs flag register
			jbe .check_speed_negative				;angle <= 360	
			fisub dword [angleLimit]
		
		
		.check_speed_negative:
			fstp qword [edi+ANGLE]
		
			call generate_random
			xor eax, eax
			mov ax, word [seed]
			
			mov dword [var1], eax
			
			finit												;generate speed in the range of [-10, 10] and add it to the original speed
			fild dword [var1]
			fidiv dword [var2]
			fimul dword [boundSpeed]
			fisub dword [halfBoundSpeed]
			fadd qword [edi+SPEED]
			
			;check negative
			ficom dword [max_bound]		;x == 800
			fstsw ax									;copy the status word to the AX register
			sahf											;copy the condition bits in the CPUs flag register
			jb .speed_upper_bound			;x < 800
			fild dword [zero]
			;fabs
			;fisub dword [boardLimit]
			;fabs
			jmp .end_speed_checking
			
			.speed_upper_bound:
			ficom dword [boardLimit]		;speed == 100
			fstsw ax									;copy the status word to the AX register
			sahf											;copy the condition bits in the CPUs flag register
			jbe .speed_lower_bound			;speed <= 100
			fild dword [boardLimit]
			;fisub dword [boardLimit]
			jmp .end_speed_checking
			
		.speed_lower_bound:
			mov dword [var1], 0
			ficom dword [var1]					;speed == 0
			fstsw ax									;copy the status word to the AX register
			sahf											;copy the condition bits in the CPUs flag register
			jae .end_speed_checking					;speed >= 0
			fild dword [zero]
			;fiadd dword [boardLimit]
	
		
		.end_speed_checking:
			fst qword [edi+SPEED]
			
		
		
		popad					;from generate_bound_angle_and_speed
		
		
		end_method
		
		
	initiate_drone:	
		start_method
		get_drone_info
		push eax                                   ;drone->drone_num=current_drone
		mov eax , dword [CURRENT_DRONE]
		mov dword [edi],eax
		mov byte[edi+ELIMINATED],0
		pop eax
		;------------generate point-------------
		
		pushad

		call generate_random
		xor eax, eax
		mov ax, word [seed]
		
		mov dword [var1], eax
		mov dword [var2], MAXRANDOM
		
		;generate x
		finit													;get x in range of [0, 100]
		fild dword [var1]
		fidiv dword [var2]
		fimul dword [boardLimit]

		
		mov dword [edi], esi   ;drone_info->id=esi
		fstp qword [edi+X]  ;drone->x=x
		
		call generate_random
		xor eax, eax
		mov ax, word [seed]
		
		mov dword [var1], eax
		
		;generate y
		finit													;get y in range if [0, 100]
		fild dword [var1]
		fidiv dword [var2]
		fimul dword [boardLimit]

		fst qword [edi+Y]
				
		popad												;from generate_point
			
		;----------------generate angle and speed--------------
		pushad
		
		call generate_random
		xor eax, eax
		mov ax, word [seed]
		
		mov dword [var1], eax
		mov dword [var2], MAXRANDOM
		
		;generate angle
		finit												;get angle in the range [0, 360]
		fild dword [var1]
		fidiv dword [var2]
		fimul dword [angleLimit]

		fst qword [edi+ANGLE]
		
		call generate_random
		xor eax, eax
		mov ax, word [seed]
		
		mov dword [var1], eax
		
		;generate speed
		finit												;get speed in the range [0, 100]
		fild dword [var1]
		fidiv dword [var2]
		fimul dword [boardLimit]
		fst qword [edi+SPEED]
		
		
		popad											;from generate_angle_and_speed
		
		end_method
		
    
	
	may_destroy: 
		push ebp
        mov ebp,esp
		pushad
		get_drone_info
		transfer_ctrl dword [target_co_index]
		cmp byte [TARGET_ANSWER],0
		je .not_destroyed
		add dword [edi+DESTROYED_COUNTER],1
		.not_destroyed:
		
		popad
		mov esp,ebp
		pop ebp
		ret

	
    drone_func:
		call initiate_drone
		.loop:
			call move_forward
			call may_destroy
			transfer_ctrl dword [co_index]
		jmp .loop
    
    
        
    
        
        
        
