CODEP equ 0; offset of pointer to co-routine function in co-routine struct 
SPP equ 4; offset of pointer to co-routine stack in co-routine struct
STKSIZE equ 16*1024
N_OF_CORS_WO_DRONES equ 3
RNG_ROTATION equ 16
MAXRANDOM equ 65535

%define DRONE_N_ARG 4
%define FULL_CYCLES_ARG 8
%define STEPS_ARG 12
%define DISTANCE_ARG 16
%define SEED_ARG 20


;these define the location of each variable in the drone_Info struct
%define DRONE_ID 0
%define X 4
%define Y 12
%define ANGLE 20
%define SPEED 28
%define DESTROYED_COUNTER 36
%define ELIMINATED 40
%define DRONE_INFO_STRUCT_SIZE 41


section .rodata
    float_format: db  " %f",0
    
section .data
    global numco ;total number of coroutines
    global co_index ;scheduler index
    global target_co_index ;target index
    global seed
    global targetDistance
    global total_drones
    global STEPS
    global FULL_CYCLES
    target_co_index: dd 0
    total_drones: dd 0
    co_index: dd 0
    numco: dd 0
    targetDistance: dq 0.0
    seed: dw 0
    STEPS: dd 0
    FULL_CYCLES: dd 0


section .bss
    global DRONE_ARRAY
    global CORS
    CURR: resd 1
    SPT: resd 1   ; temporary stack pointer
    SPMAIN: resd 1   ; stack pointer of main
    CORS: resd 1 ; pointer to cors array
    DRONE_ARRAY: resd 1
    
section .text
    global main
    global resume
    global generate_random
    global end_co
    extern malloc
    extern calloc
    extern free
    extern printf
    extern sscanf
    extern printer_function
    extern drone_func
    extern target_func
    extern scheduler_func


    ;push in ecx pointer to string (char*)
    %macro str_to_int_mac 0
        push ecx
        call str_to_int
        add esp,4
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
    
    %macro malloc_mac 1
        push edx
        push ebx
        push ecx
        push dword %1
        call malloc
        add esp,4
        pop ecx
        pop ebx
        pop edx
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
    
    generate_random:  ;generates a random number into the seed label
        push ebp
        mov ebp,esp
        pushad
        xor eax, eax
        mov esi, RNG_ROTATION
        mov ax , word [seed]
        
        .rng_loop:
        cmp esi,0
        je .end_rng_loop
        
        push eax ;get lsb
        and ax,0x0001
        mov bx,ax
        pop eax
        
        push eax ;get 14th bit
        shr ax,2
        and ax,0x0001
        mov cx,ax
        pop eax
        
        push eax ;get 13th bit
        shr ax,3
        and ax,0x0001
        mov dx,ax
        pop eax
        
        push eax ;get 11th bit
        shr ax,5
        and ax,0x0001
        mov di,ax
        pop eax
        
        xor bx,cx
        xor bx,dx
        xor bx,di
        
        ror bx,1
        shr ax,1
        or ax,bx
        
        dec esi
        jmp .rng_loop
        
        .end_rng_loop:
        
        mov word [seed],ax
        
        popad
        mov esp,ebp
        pop ebp
        ret

    str_to_int:  ;int str_to_int(char* str) converts a string to integer
        start_method
        mov edx,dword [ebp+8]
        xor eax,eax
        .Next_Char:
            movzx ecx,byte [edx] ; convert and add first number
            sub ecx,'0'
            imul eax,10
            add eax,ecx
            inc edx
            cmp byte [edx],0
            je .done
            jmp .Next_Char
        .done:
        end_method
    
    
    initCo:
        start_method
        
        mov ebx,[ebp+8]
        mov ecx , dword [CORS] ;ecx=ptr to CORS struct
        shl ebx,3
        add ebx,ecx

        mov eax, dword [ebx+CODEP]
        mov dword [SPT], esp
        mov esp, dword [ebx+SPP]
        push eax
        pushfd
        pushad
        mov dword [ebx+SPP], esp
        mov esp, dword [SPT]
        
        end_method
    
    
    startCo:
        start_method
        
        pushad; save registers of main ()
        mov dword [SPMAIN], esp; save ESP of main ()
        mov ebx, dword [ebp+8]; gets ID of a scheduler co-routine
        mov ecx , dword [CORS] ;ecx=ptr to CORS struct
        shl ebx,3
        add ebx,ecx
        jmp do_resume; resume a scheduler co-routine
        
    end_co:
        mov esp,dword [SPMAIN]
        popad
        end_method
        
    
    
    resume:
        pushfd
        pushad
        mov edx,[CURR]
        mov [edx+SPP],esp
    do_resume:
        mov esp,[ebx+SPP]
        mov [CURR],ebx
        popad
        popfd
        ret
    
    allocate_cors:
        start_method
        
        mov edx,dword [numco]
        shl edx,3
        malloc_mac edx
        mov dword [CORS],eax ;moving pointer to allocated array into the CORS label
        
        
        mov ebx,dword [CORS]
        pushad
        mov edx,dword [numco]
        sub edx,N_OF_CORS_WO_DRONES
        xor ecx,ecx
        .drone_cors_loop:
            cmp ecx,edx
            je .end_drone_cors_loop
            
            mov dword [ebx+CODEP+8*ecx],drone_func
            
            malloc_mac STKSIZE
            add eax,STKSIZE
            
            mov dword [ebx+SPP+8*ecx],eax
            inc ecx
            jmp .drone_cors_loop
        .end_drone_cors_loop:
        
        ;allocating correct pointers and stack for scheduler and target and print cors
        popad
        mov edx,dword [numco]
        dec edx
        mov dword [ebx+8*edx],scheduler_func
        malloc_mac STKSIZE
        add eax,STKSIZE
        mov dword [ebx+4+8*edx],eax
        
        dec edx
        mov dword [ebx+8*edx],printer_function
        malloc_mac STKSIZE
        add eax,STKSIZE
        mov dword [ebx+4+8*edx],eax
        
        dec edx
        mov dword [target_co_index],edx
        mov dword [ebx+8*edx],target_func
        malloc_mac STKSIZE
        add eax,STKSIZE
        mov dword [ebx+4+8*edx],eax


        end_method
    
    init_from_main_args:                ;called in start of main to read the program args and initialize variables
        start_method
        sub esp,4
        mov ecx,dword [ebx+DRONE_N_ARG]

        str_to_int_mac

        mov dword [total_drones],eax
        add eax,N_OF_CORS_WO_DRONES ;enough space for drone cors and target+scheduler cors
        mov dword [numco],eax
        dec eax
        mov dword [co_index],eax

        mov ecx , dword [ebx+FULL_CYCLES_ARG]
        str_to_int_mac

        mov dword [FULL_CYCLES],eax

        mov ecx, dword [ebx+STEPS_ARG]
        str_to_int_mac

        mov dword [STEPS],eax

        mov ecx, dword [ebx+SEED_ARG]
        str_to_int_mac
        mov word [seed],ax

        mov ecx, dword [ebx+DISTANCE_ARG]
        lea edi,[ebp-4]
        push edi
        push float_format
        push ecx
        call sscanf
        add esp,12

        finit
        fld dword [ebp-4]
        fstp qword [targetDistance]
        end_method


    main:
        start_method
        
        mov ebx,dword [ebp+12]

        pushad
        call init_from_main_args
        popad

        pushad
        call allocate_cors ;allocating all the necessary memory , for the CORS struct and the stacks of each coroutine
        popad

        call init_drone_array
        
        xor ecx,ecx
        
        .init_loop:
            cmp ecx,dword [numco]
            je .end_init_loop
            pushad
            push ecx
            call initCo
            add esp,4
            popad
            inc ecx
            jmp .init_loop
        .end_init_loop:
        
        
        push dword [co_index]
        call startCo
        add esp,4
        end_method
    
    
    init_drone_array: ;initializes and allocates memory for the drone_info array and puts it in DRONE_ARRAY label
        start_method

        mov ecx, dword [numco]
        sub ecx,N_OF_CORS_WO_DRONES ;get total number of drones

        pushad
        push dword 4 ;size of ptr
        push ecx
        call calloc
        add esp,8
        mov dword [DRONE_ARRAY],eax ;put the array ptr 
        popad

        mov edx ,dword [DRONE_ARRAY] ;eax ptr to array,ecx holds total num of drones
        xor ebx,ebx
        .init_struct_loop:
            cmp ebx,ecx
            je .end_loop
            push edx
            lea edx,[edx+ebx*4]
            malloc_mac DRONE_INFO_STRUCT_SIZE
            mov dword [edx],eax
            pop edx
            inc ebx
            jmp .init_struct_loop
        .end_loop:

        end_method

            
            
            
