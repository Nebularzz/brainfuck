.section .bss
memory: .skip 32768

.section .text
.global _start

_start:
  movq $memory, %rdi
{s}
  movq $60, %rax
  xorq %rdi, %rdi
  syscall

outp:
  movq $1, %rax
  movq %rdi, %rsi
  movq $1, %rdi
  movq $1, %rdx
  syscall
  movq %rsi, %rdi
  ret

inp:
  xorq %rax, %rax
  movq %rdi, %rsi
  xorq %rdi, %rdi
  movq $1, %rdx
  syscall
  movq %rsi, %rdi
  ret
