.section .text
    .global _start

    print:
        pushq %rdi

        # write(stdout, %rdi, 1)
        movq $1, %rax
        movq %rdi, %rsi
        movq $1, %rdi
        movq $1, %rdx
        syscall

        popq %rdi
        retq

    input:
        pushq %rdi

        # read(stdin, %rdi, 1)
        xorq %rax, %rax
        movq %rdi, %rsi
        xorq %rdi, %rdi
        movq $1, %rdx
        syscall

        popq %rdi
        retq

    _start:
        # mmap(0, 65536, PROT_READ | PROT_WRITE, MAP_ANONYMOUS | MAP_PRIVATE, -1, 0)
        movq $9, %rax
        xorq %rdi, %rdi
        movq $65536, %rsi
        movq $3, %rdx
        movq $34, %r10
        movq $-1, %r8
        xorq %r9, %r9
        syscall

        movq %rax, %rdi # move array pointer into %rdi
        pushq %rax # save array pointer for munmap
        cmp $-1, %rax # check for error and exit if erroneous
        je EXIT_FAILURE
