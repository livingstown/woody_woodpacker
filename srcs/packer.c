#include "../includes/woody.h"

static uint32_t			align(uint32_t offset)
{
	if (offset % 16 != 0)
	{
		return (16 - (offset % 16));
	}
	return (0);
}

static void				fill_asm_var(void *ptr, int value_tofill)
{
	int *match;
	
	match = (int *)((uint8_t *)ptr);
	// printf("MATCH !!!!!!!!! %x\n", *match);
	*match = value_tofill;
}

/**
 * We are searching section based on given segment address
 **/
static Elf64_Shdr		*section_d_assaut(t_info info, Elf64_Addr addr)
{
	Elf64_Ehdr 			*header;
	Elf64_Shdr  		*section;
	int 				i = -1;

	header = (Elf64_Ehdr *)info.file;
	section = (Elf64_Shdr *)memory_protect(info.file + header->e_shoff, info);

	while (i++ < header->e_shnum - 1)
	{
		if (&section[i + 1])
		{
			if (section[i].sh_addr <= addr && section[i + 1].sh_addr > addr)
			{
				return (&section[i]);
			}
		}
	}
	printf("WTF ? Section not found, we exit");
	clean_exit(info);
	exit(EXIT_FAILURE);
}

/**
 * If perm is given, we search a segment based on perm
 * if check_size is TRUE we also check if this segment had enough space for our exploit
 **/
Elf64_Phdr				*search_segment(t_info info, uint32_t perm, uint8_t check_size)
{
	Elf64_Ehdr 			*header;
	Elf64_Phdr			*pheader;
	uint32_t			cave_size;
	int					i = -1;
	
	header = (Elf64_Ehdr *)info.file;
	pheader = (Elf64_Phdr *)memory_protect(info.file + header->e_phoff, info);
	while(i++ < header->e_phnum)
	{
		if (pheader[i].p_type == PT_LOAD && i + 1 < header->e_phnum)
		{
			if (perm == pheader[i].p_flags || perm == 0)
			{
				if (check_size == 1)
				{
					cave_size = pheader[i + 1].p_offset - (pheader[i].p_offset + pheader[i].p_filesz);
					if ((int)cave_size > ((int)info.exploit_size + 256 + ALIGN))
					{
						// debug("Found segment with enough space\n");
						// printf("Cave size : %x (%d)\n", cave_size, cave_size);
						return (&pheader[i]);
					}
				}
				else
				{
					return (&pheader[i]);
				}
			}
		}
	}
	return (NULL);
}

static void			set_right_perm(t_info info, Elf64_Phdr *current_segment)
{
	Elf64_Phdr		*segment_txt;

	if (current_segment->p_flags != (PF_R + PF_X) && current_segment->p_flags != (PF_R + PF_X + PF_W))
	{
		segment_txt = search_segment(info, PF_R + PF_X, 0);
		if (segment_txt == NULL)
		{
			debug("Wtf there is no exec segment ?, on exit");
			clean_exit(info);
			exit(EXIT_FAILURE);
		}
		segment_txt->p_flags = (PF_R + PF_X + PF_W);
	}
	current_segment->p_flags = (PF_R + PF_X + PF_W);
}

/**
 * This is the core of the program
 * we first verify if we use segment text, otherwise we have to change perm of segment text too
 * we inject print_woody code (our malicious exploit) and fill print_woody diff
 * we cipher since actual program entry point to end of text segment 
 * we inject in file our decipher function after print_woody (ciphered)
 * we fill asm variable needed by our decipher function
 * we write our keystream needed by our decipher function
 * finally, we change the entry point to point to our deciphering function
 **/
void				packer(t_info info, Elf64_Phdr *pheader)
{
	Elf64_Ehdr 		*header;
	uint32_t		woody_size = ((char *)&print_woody_end - (char *)&print_woody);
	uint32_t		decipher_size = (char *)&end_decipher - (char *)&decipher;
	uint32_t		alignement;
	uint32_t		woody_offset;
	uint32_t		decipher_offset;
	Elf64_Shdr		*section;
	
	
	header = (Elf64_Ehdr *)info.file;
	
	set_right_perm(info, pheader);

	woody_offset = pheader->p_offset + pheader->p_filesz;
	alignement = align(woody_offset);
	woody_offset += align(woody_offset);

	// printf("WOODY OFFSET : %x\nWOODY SIZE : %x\n", woody_offset, woody_size);
	ft_memcpy(memory_protect(info.file + woody_offset, info), (void *)&print_woody, woody_size);
	
	// printf("OLD ENTRY : %lx\n", header->e_entry);

	fill_asm_var(memory_protect(info.file + woody_offset + ((void *)&diff - (void *)&print_woody), info), (pheader->p_vaddr + pheader->p_memsz + alignement) - header->e_entry);

	section = section_d_assaut(info, header->e_entry);
	// printf("offset : %lx\naddr : %lx\nsize : %lx\n", section->sh_offset, section->sh_addr, section->sh_size);
	// printf("START CIPHER : %lx\n", section->sh_offset + (header->e_entry - section->sh_addr));
	cipher(memory_protect(info.file + section->sh_offset + (header->e_entry - section->sh_addr), info), info.key, section->sh_size - (header->e_entry - section->sh_addr), info.keystream);
	
	decipher_offset = woody_offset + woody_size;
	alignement += align(decipher_offset);
	decipher_offset += align(decipher_offset);
	
	ft_memcpy(memory_protect(info.file + decipher_offset, info), (void *)&decipher, decipher_size);
	ft_memcpy(memory_protect(info.file + decipher_offset + decipher_size, info), info.keystream, 256);

	// printf("input diff : %lx (%ld)\n", (pheader->p_vaddr + pheader->p_memsz + alignement + woody_size) - header->e_entry, (pheader->p_vaddr + pheader->p_memsz + alignement + woody_size) - header->e_entry);
	fill_asm_var(memory_protect(info.file + decipher_offset + ((void *)&input_diff - (void *)&decipher), info), (pheader->p_vaddr + pheader->p_memsz + alignement + woody_size) - header->e_entry);
	fill_asm_var(memory_protect(info.file + decipher_offset + ((void *)&input_len - (void *)&decipher), info), section->sh_size - (header->e_entry - section->sh_addr));
	fill_asm_var(memory_protect(info.file + decipher_offset + ((void *)&woody_diff - (void *)&decipher), info), decipher_offset - woody_offset);
	

	header->e_version = 42;
	header->e_entry = pheader->p_vaddr + pheader->p_memsz + woody_size + alignement;
	// printf("Final Entry point (decipher) : %lx\n", header->e_entry);
	pheader->p_memsz += info.exploit_size + align(woody_size) + 256;	//exploit size + alignement
	pheader->p_filesz += info.exploit_size + align(woody_size) + 256;

	write(info.new_fd, info.file, info.file_size);
	print_key(info.key);
	print_pecker();
	clean_exit(info);
}