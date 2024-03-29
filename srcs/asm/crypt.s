
section .text
global	cipher


cipher:

	push rbp
	mov rbp, rsp
	sub rsp, 304
	mov QWORD [rsp], rdi 			;save for param input pointer
	mov QWORD [rsp + 8], rsi		;save for param key pointer
	mov QWORD [rsp + 16], rdx		;save for param input_len
	mov DWORD [rsp + 24], -1		;i = -1
	mov DWORD [rsp + 28], 0			;j = 0
									;rsp + 32 = tab
	mov QWORD [rsp + 288], rcx		;rsp + 288 = keystream
	mov DWORD [rsp + 296], -1		;k = -1
	jmp .init

.init:								;Create tab[255] = 0,1,2,3...255
	mov eax, DWORD [rsp + 24]
	cmp eax, 255
	jge .shuffle
	add eax, 1
	mov DWORD [rsp + 24], eax
	mov edx, eax
	cdqe							;sign eax and put it to rax for address alignement
	mov BYTE [rsp + 32 + rax], dl	;dl is juste a byte register that contain 'i'
	jmp .init

.shuffle:

	mov DWORD [rsp + 24], -1		; i = -1
	mov eax, DWORD [rsp + 24]		; i
	cmp eax, 255
	jge .keystream
	add eax, 1
	mov DWORD [rsp + 24], eax		; i += 1;
	cdqe							; double to quad word
	movzx eax, BYTE [rsp + 32 + rax]; tab[i]

	mov edi, DWORD [rsp + 28]		; j
	add edi, eax					; j + tab[i]

	mov eax, DWORD [rsp + 24]		; i
	cdqe
	and eax, 15						; i & 15
	mov rcx, rax					; i & 15
	mov QWORD rax, [rsp + 8]		; pointer key
	add rax, rcx					; pointer key[i & 15]
	movzx eax, BYTE [rax]			; pointer key[i & 15]
	add eax, edi					; j + tab[i] + pointer key[i & 15]
	and eax, 255					;( j + tab[i] + pointer key[i & 15]) & 255
	mov DWORD [rsp + 28], eax		;j = ( j + tab[i] + pointer key[i & 15]) & 255
	jmp .swap

.swap:

	mov eax, DWORD [rsp + 24]		; i;
	cdqe							; double to quad word
	movzx eax, BYTE [rsp + 32 + rax]; tab[i]
	mov edi, eax					; edi = tab[i]

	mov eax, DWORD [rsp + 28]		; j;
	cdqe							; double to quad word
	movzx eax, BYTE [rsp + 32 + rax]; tab[j]
	mov esi, eax					; esi = tab[j]
	xor edi, esi					; edi = tab[i] ^ tab[j]
	xor esi, edi					; esi = tab[j] ^ edi
	xor edi, esi					; edi = edi ^ esi
	
	mov eax, DWORD [rsp + 28]		; j
	mov edx, esi
	cdqe
	mov BYTE [rsp + 32 + rax], dl	; tab[j] = esi

	mov eax, DWORD [rsp + 24]		; i
	mov edx, edi
	cdqe
	mov BYTE [rsp + 32 + rax], dl	; tab[i] = edi

	jmp .shuffle + 8

.keystream:
	mov DWORD [rsp + 24], 0			; i = 0
	mov DWORD [rsp + 28], 0			; j = 0

	mov eax, DWORD [rsp + 296]		; k;
	cmp eax, 255
	jge .rc4
	mov eax, DWORD [rsp + 296]		;k
	add eax, 1
	mov DWORD [rsp + 296], eax		;k++

	mov eax, DWORD [rsp + 24]		; i;
	add eax, 1						; i += 1
	and eax, 255					; i &= 255
	mov DWORD [rsp + 24], eax		; save i
	cdqe
	movzx ecx, BYTE [rsp + 32 + rax]; tab[i]
	mov eax, DWORD [rsp + 28]		; j;
	add eax, ecx					; j + tab[i]
	and eax, 255					; j &= 255
	mov DWORD [rsp + 28], eax		; save j

	;swap
	mov eax, DWORD [rsp + 24]		; i;
	cdqe							; double to quad word
	movzx eax, BYTE [rsp + 32 + rax]; tab[i]
	mov edi, eax					; edi = tab[i]

	mov eax, DWORD [rsp + 28]		; j;
	cdqe							; double to quad word
	movzx eax, BYTE [rsp + 32 + rax]; tab[j]
	mov esi, eax					; esi = tab[j]
	xor edi, esi					; edi = tab[i] ^ tab[j]
	xor esi, edi					; esi = tab[j] ^ edi
	xor edi, esi					; edi = edi ^ esi
	
	mov eax, DWORD [rsp + 28]		; j
	mov edx, esi
	cdqe
	mov BYTE [rsp + 32 + rax], dl	; tab[j] = esi


	mov eax, DWORD [rsp + 24]		; i
	mov edx, edi
	cdqe
	mov BYTE [rsp + 32 + rax], dl	; tab[i] = edi
	;endswap

	mov eax, DWORD [rsp + 24]		;i
	cdqe
	movzx ecx, BYTE [rsp + 32 + rax]; tab[i]

	mov eax, DWORD [rsp + 28]		;j
	cdqe
	movzx edx, BYTE [rsp + 32 + rax]; tab[j]

	add ecx, edx					; tab[i] + tab[j]
	and ecx, 255					; (tab[i] + tab[j]) & 255

	mov eax, ecx
	cdqe
	movzx ecx, BYTE [rsp + 32 + rax]; tab[(tab[i] + tab[j]) & 255]

	mov rsi, [rsp + 288]
	mov eax, DWORD [rsp + 296]		;k
	cdqe
	mov BYTE [rsi + rax], cl	; keystream[k] = tab[(tab[i] + tab[j]) & 255]
	jmp .keystream + 16


.rc4:
	mov DWORD [rsp + 24], -1			; i = -1

	mov eax, DWORD [rsp + 24]			; i
	mov ecx, DWORD [rsp + 16]			; input_len
	cmp eax, ecx
	jge .exit
	add eax, 1
	mov DWORD [rsp + 24], eax			; i += 1
	mov ecx, eax						; save i
	and eax, 255
	cdqe
	mov rdi, [rsp + 288]
	movzx edx, BYTE [rdi + rax]			; keystream[i & 255]
	mov rsi, [rsp]						; get input pointer
	mov eax, ecx						; retrieve saved i
	cdqe
	movzx ecx, BYTE [rsi + rax]			; input[i]
	xor ecx, edx
	mov rsi, [rsp]						; input[i] ^ keystream[i & 255]
	mov BYTE [rsi + rax], cl			; input[i] ^= keystream[i & 255]
	jmp .rc4 + 8

.exit:
	mov rax, QWORD [rsp + 288]
	mov	rsp, rbp
	pop	rbp
	ret