
    # munmap(*saved pointer from mmap*, 65536)
    popq %rdi
    movq $11, %rax
    movq $65535, %rsi
    syscall

    # check for error if and jump if erroneous
    cmp $-1, %rax
    je EXIT_FAILURE

    # return 0
    movq $60, %rax
    xorq %rdi, %rdi
    syscall

    # return 1
    EXIT_FAILURE:
        movq $60, %rax
        movq $1, %rdi
        syscall
