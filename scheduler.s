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
    winner_str: db "The Winner is drone: %d , With %d destroyed targets",10,0

section .data
    extern STEPS
    extern FULL_CYCLES
    extern total_drones
    extern numco ;total number of coroutines
    extern co_index ;scheduler index
    extern DRONE_ARRAY
    extern CORS
    extern target_co_index
    global CURRENT_DRONE
    CURRENT_DRONE: dd 0
    drones_left: dd 0
    scheduler_running_index: dd 0   ;this is i=0 used for the round robin execution
    CURRENT_DIVISION: dd 0
    CURRENT_REMAINDER: dd 0

section .text
    extern resume
    extern printf
    extern end_co
    global scheduler_func
    %macro transfer_ctrl 1
            push ecx
            mov ecx,%1
            mov ebx, dword [CORS]
            shl ecx,3
            add ebx,ecx
            pop ecx
            call resume
    %endmacro

    %macro get_drone_info_scheduler 0
		mov edi,dword [DRONE_ARRAY]  ;ptr to array
		lea edi, [edi+4*edx]  ;ptr to array+drone_index
		mov edi, dword [edi] ;ptr to drone_info
	%endmacro

    scheduler_func:                            ;scheduler implementation 
        
        push eax                                ;initializing the drones_left variable
        mov eax,dword [total_drones]
        mov dword [drones_left],eax
        pop eax

        transfer_ctrl dword [target_co_index]  ;calling target for the first time to initialize it

    .scheduler_loop:
        mov eax,dword [scheduler_running_index]          ;calculating i/N and getting the remainder
        xor edx,edx
        div dword [total_drones]                ;now edx=i%N
        mov dword [CURRENT_REMAINDER],edx       ;storing the values for later
        mov dword [CURRENT_DIVISION],eax

        get_drone_info_scheduler                ;edi=drone_info* to current drone

        cmp byte [edi+ELIMINATED],1
        je .drone_is_eliminated                ;if (current_drone->eliminated==0) then run regular drone cor
            mov dword [CURRENT_DRONE],edx
            transfer_ctrl dword [CURRENT_DRONE]
        
        .drone_is_eliminated:
        
        mov eax,dword [scheduler_running_index] ;calculating i/STEPS and getting the remainder
        xor edx,edx
        div dword [STEPS]                       ;now edx=i%STEPS
        cmp edx,0
        jne .no_board_print
            mov edx,dword [co_index]
            dec edx
            transfer_ctrl edx
        .no_board_print:
        
        
        cmp dword [CURRENT_REMAINDER],0         ;if (i/N)%R == 0 && i%N ==0
            jne .not_elimination_round
            mov eax,dword [CURRENT_DIVISION]
            xor edx,edx
            div dword [FULL_CYCLES]             ;edx= (i/N)%R
            cmp edx,0
                jne .not_elimination_round
                cmp dword [scheduler_running_index],0
                je .not_elimination_round
                call eliminate_drone
        .not_elimination_round:
        inc dword [scheduler_running_index]     ;i++

        cmp dword [drones_left],1
        jne .no_winner
            call get_winning_drone
            mov edi,dword [DRONE_ARRAY]  ;ptr to array
		    lea edi, [edi+4*eax]  ;ptr to array+drone_index
		    mov edi, dword [edi] ;ptr to drone_info
            mov edi,dword [edi+DESTROYED_COUNTER]
            inc eax
            pushad
            push edi
            push eax
            push winner_str
            call printf
            add esp,12
            popad
            jmp end_co
        .no_winner:
    jmp .scheduler_loop


    eliminate_drone:
        push edi
        push ecx
        push ebx
        push edx
		xor ecx ,ecx
        xor eax,eax
        .get_first_active_drone_destroyed_targets:  ;gets the first active drones destroyed targets into eax
            cmp ecx,dword [total_drones]
            je .end_get_first
            mov edi,dword [DRONE_ARRAY]  ;ptr to array
            lea edi,[edi+4*ecx]
            mov edi,dword [edi]
            movzx ebx,byte [edi+ELIMINATED]
            inc ecx
            cmp ebx,1                               ;if the current drone is eliminated
            je .get_first_active_drone_destroyed_targets
            mov eax,dword [edi+DESTROYED_COUNTER]
            mov edx,dword [edi+DRONE_ID]
        .end_get_first:
       
        .elimination_loop:                          ;looping on the drones array and getting drone with lowest targets destroyed
            cmp ecx,dword [total_drones]
            je .loop_done
            mov edi,dword [DRONE_ARRAY]  ;ptr to array
            lea edi,[edi+4*ecx]
            mov edi,dword [edi]
            movzx ebx,byte [edi+ELIMINATED]
            cmp ebx,1                               ;if the current drone is eliminated
            je .skip_drone
            cmp dword [edi+DESTROYED_COUNTER],eax
            jae .skip_drone
                mov edx,dword [edi+DRONE_ID]
                mov eax,dword [edi+DESTROYED_COUNTER]
            .skip_drone:
            inc ecx
            jmp .elimination_loop
        .loop_done:
        
        mov edi,dword [DRONE_ARRAY]  ;ptr to array
        lea edi,[edi+4*edx]
        mov edi,dword [edi]
        mov byte [edi+ELIMINATED],1
        dec dword [drones_left]
        
        pop edx
        pop ebx
        pop ecx
        pop edi
        ret


        get_winning_drone:
        
        xor ecx,ecx
        .get_first_active_drone_for_win:  ;gets the first active drones destroyed targets into eax
            cmp ecx,dword [total_drones]
            je .got_winning_drone
            mov edi,dword [DRONE_ARRAY]  ;ptr to array
            lea edi,[edi+4*ecx]
            mov edi,dword [edi]
            movzx ebx,byte [edi+ELIMINATED]
            inc ecx
            cmp ebx,1                               ;if the current drone is eliminated
            je .get_first_active_drone_for_win
            mov eax,dword [edi+DRONE_ID]
        .got_winning_drone:
        ret