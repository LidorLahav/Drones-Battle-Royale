;these define the location of each variable in the drone_Info struct
%define DRONE_ID 0
%define X 4
%define Y 12
%define ANGLE 20
%define SPEED 28
%define DESTROYED_COUNTER 36
%define ELIMINATED 40
%define DRONE_INFO_STRUCT_SIZE

section .rodata
    DRONE_DESCRIPTION_STR: db " %d, %.2f , %.2f , %.2f , %.2f , %d ",10,0
    delimiter: db "-------------------------------------------------------",10,0

section .data
    extern DRONE_ARRAY
    extern TARGET_LOCATION
    extern numco
    extern CORS
    extern co_index
    global printer_function


section .text
    extern printf
    extern resume

    %macro transfer_ctrl 1
            push ecx
            mov ecx,%1
            mov ebx, dword [CORS]
            shl ecx,3
            add ebx,ecx
            pop ecx
            call resume
    %endmacro

    printer_function:
        finit
        .inf_loop:

        pushad
        push delimiter
        call printf
        add esp,4
        popad

        mov ecx,dword [numco]
        sub ecx,3                          ;doing i<num_of_drones
        mov eax,dword [DRONE_ARRAY]
        xor ebx,ebx
        
        .printer_loop:
            cmp ebx,ecx
            je .end_printer_loop

            pushad
            lea eax,[eax+4*ebx]
            mov eax,dword [eax]     ;eax=DRONE_ARRAY->info_array[ebx]->drone_info
            
            cmp byte [eax+ELIMINATED],1
            je .dont_print_drone

            push dword [eax+DESTROYED_COUNTER]
            
            sub esp,8
            fld qword [eax+SPEED]
            fstp qword [esp]
            
            sub esp,8
            fld qword [eax+ANGLE]
            fstp qword [esp]

            sub esp,8
            fld qword [eax+Y]
            fstp qword [esp]

            sub esp,8
            fld qword [eax+X]
            fstp qword [esp]
            
            push dword [eax]

            push DRONE_DESCRIPTION_STR
            
            call printf
            add esp,44

            .dont_print_drone:
            popad
            
            inc ebx
            jmp .printer_loop
        .end_printer_loop:
        
        transfer_ctrl dword [co_index]      ;transfering control to scheduler after print
        
        jmp .inf_loop
        