bits 64
default rel

%define MSG_CAP    512
%define PREFIX	   '{"content": "'
%strlen PRELEN     PREFIX

section .data
	; Curl path
	prog db "/usr/local/bin/curl", 0

	; Arguments
	arg1 db "-X", 0
	arg2 db "POST", 0
	arg3 db "-H", 0
	arg4 db "Content-Type: application/json", 0
	arg5 db "-d", 0

	; JSON payload
	payload db PREFIX, MSG_CAP dup (0), '"}', 0

	; msg start
	message_start equ payload + PRELEN
	suffix_bytes equ 3

	; Discord webhook
	webhook_url db "https://discord.com/api/webhooks/1410146214359335035/UIwjmtSb5COBNI8jXLN0UHGblXeM3gJ5h6o-R9r-LiGp7027rhh5b_vC9-osCyAQEpFJ", 0

	; Arg array
	argv dq prog, arg1, arg2, arg3, arg4, arg5, payload, webhook_url, 0

	; Envp array
	envp dq 0

	; Prompt
	prompt db "What do you want to send? (500 bytes): "
	prompt_end:

	confirm db "done", 0

section .text
	global _start

_start:
	call _printPrompt
	call _getMessage
	call _executeCurl
	call _printConfirmation

	; If exeve fails
	mov rax, 60	; Syscall number for exit
	mov rdi, 1	; Exit code 1
	syscall

_printConfirmation:
	mov rax, 1	; 0: stdin, 1: stdout, 2: stderr?
	mov rdi, 1	; fd
	lea rsi, [rel confirm] ; Buffer
	mov rdx, 4	; Buffer byte len
	syscall
	ret

_getMessage:
	mov rax, 0	; 0: stdin, 1: stdout, 2: stderr?
	mov rdi, 0	; fd
	lea rsi, [rel message_start]
	mov rdx, MSG_CAP - suffix_bytes	; Buffer message byte len
	syscall

	; rax = number of bytes read; strip trailing '\n' (0x0A) and '\r' (0x0D)
	test rax, rax ; did we read anything?
	jz .close_json ; if no bytes, skip to close

	mov rcx, rax ; rcx = bytes read len
	dec rcx		; rcx = index of last char

	cmp byte [message_start + rcx], 10	; is last char '\n' (LF, 0x0A)
	jne .check_cr ; if not LF, check for CR
	dec rax		; drop LF
	jmp .check_cr_after

.check_cr:
	cmp byte [message_start + rcx], 13	; is last char '\r' (CR, 0x0D)
	jne .check_cr_after
	dec rax		; drop CR
	dec rcx		; move to new last char

.check_cr_after:
	cmp rax, 0	; did we strip down to 0 chars?
	jz .close_json ; if empty, close

	cmp byte [message_start + rcx], 13 ; check for CR before LF (Windows CLRF)
	jne .close_json ; if not, close
	dec rax	; drop CR

.close_json:
	; Complete JSON payload
	mov byte [message_start + rax], '"'
	mov byte [message_start + rax + 1], '}'
	mov byte [message_start + rax + 2], 0
	ret

_printPrompt:
	mov rax, 1	; 0: stdin, 1: stdout, 2: stderr?
	mov rdi, 1	; File descriptor, we want to print something to the screen
	lea rsi, [rel prompt] ; Buffer for what we are printing
	mov rdx, 39	; Prompt byte len
	syscall
	ret

_executeCurl:
	mov rax, 59	; Syscall num for execve
	lea rdi, [rel prog]	; First arg: pathname
	lea rsi, [rel argv]	; Second arg: arg array
	lea rdx, [rel envp]	; Third argument: envp array
	syscall
	ret
