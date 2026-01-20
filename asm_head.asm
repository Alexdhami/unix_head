BUF_SIZE equ 128

;syscalls
OPENAT_SYSCALL equ 257

; errors
ENOENT equ -2  ; file not found
EACCES equ -13 ; permission denied

%macro write 2 ; 1 = *msg, 2 = len(msg)
    mov rax, 1
    mov rdi, 1
    mov rsi, %1
    mov rdx, %2
    syscall
%endmacro


; messages to show in stdout.
section .data
    msg_generic_error db "error opening file. :(", 10
    len_generic_error equ $-msg_generic_error

    msg_file_not_found db "no file found :(", 10
    len_file_not_found equ $-msg_file_not_found

    msg_permission_denied db "cannot open file: check permissions.", 10
    len_permission_denied equ $-msg_permission_denied

section .text
    global _start

_start:
    mov r14, 0                  ; counter for newline
    mov r15, 10                 ; max 10 lines to read
    check_arg:
        mov rcx, [rsp]          ; save argc to %rcx 
        cmp rcx, 2              ; compare argc == 2
        jb read_stdin           ; if argc less than 2 then we should read stdin and stdout that
        jmp open_file           ; otherwise open the file

    open_file:
        mov rax, OPENAT_SYSCALL ; openat(int fd, char* filepath, int mode, int flag)
        mov rdi, -100           ; FD_ATCWD
        mov rsi, [rsp + 16]     ; filepath
        mov rdx, 0              ; O_RDONLY
        mov r10, 0              ; unused
        syscall

        mov r12, rax            ; openat() returns pos value(fd) at success otherwise neg value
        mov r13, 1              ; read byte by byte from the file. So, save it to %r13 for later use

        cmp rax, ENOENT         ; if openat() returned ENOENT then 
        je file_not_found       ; jmp if equal file_not_found label

        cmp rax, EACCES         ; if openat() returned EACCES then
        je permissions_denied   ; jmp if equal permissions_denied label

        test rax, rax
        js generic_error        ; jump if signed bit to generic_error

        jmp read_loop           ; otherwise

    read_stdin:
        mov r12, 0              ; if we are in stdin, then %r12 = 0 for stdin
        mov r13, BUF_SIZE       ; length is BUF_SIZE

    read_loop:
        mov rax, 0              ; read() syscall
        mov rdi, r12            ; if stdin then (0) otherwise (new_fd) saved in %r12
        mov rsi, buf            ; *buffer
        mov rdx, r13            ; length (1) if from file otherwise (BUF_SIZE) saved in %r13
        syscall

        cmp rax, 0              ; indicates EOF
        jle exit_success

        mov rbx, rax            ; save how many bytes we read in %rbx

        cmp r13, 0              ; compare %r13 to 0 | 0 = stdin 
        je .continue            ; if stdin then go to .continue label
        jmp .is_not_stdin       ; otherwise jmp to .is_not_stdin label

        .continue:
            write buf, rbx      ; %rbx contains no. bytes we read. 1 if from file otherwise from stdin
            jmp read_loop

        .is_not_stdin:
            cmp r14, r15        ; compare counter to max_line_to_read = 10
            jge close_file      ; if greater or equal jmp to close_file
            mov al, byte[buf]   ; mov byte from buf to %al
            cmp al, 10          ; if it's newline then inc counter
            je .inc_counter 
            jmp .continue       ; otherwise .continue


        .inc_counter:
            inc r14             ; increases the counter %r14 -> %r14++
            jmp .continue       



file_not_found:
    write msg_file_not_found, len_file_not_found
    jmp exit_error

permissions_denied:
    write msg_permission_denied, len_permission_denied
    jmp exit_error

generic_error:
    write msg_generic_error, len_generic_error
    jmp exit_error

close_file:
    mov rax, 3                  ; close() syscall
    mov rdi, r12                ; fd saved in %r12
    syscall
    jmp exit_success

exit_success:
    mov rax, 60
    xor rdi, rdi
    syscall

exit_error:
    mov rax, 60
    xor rdi, 1
    syscall

section .bss
    buf resb BUF_SIZE
