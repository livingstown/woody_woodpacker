

section .text
global print_woody
global print_woody_end
global diff


print_woody:
  mov eax, 1        ; write(
  mov edi, 1        ;   STDOUT_FILENO,
  lea rsi, [rel msg]      ;   "Hello, world!\n",
  mov rdx, 14   	;   sizeof("Hello, world!\n")
  syscall           ; );

  xor edi, edi
  xor rsi, rsi
  xor rdx, rdx
  lea rax, [rel print_woody]
  mov edx, [rel diff]
  sub rax, rdx
  xor rdx, rdx
  jmp rax

;   mov rax, 60       ; exit(
;   mov rdi, 0        ;   EXIT_SUCCESS
;   syscall           ; );

diff: dd 0x41414141
msg: db "....WOODY....", 10
; msglen: equ $ - msg
print_woody_end:

