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

plus:
  addb $1, (%rdi)
  ret

minus:
  subb $1, (%rdi)
  ret

left:
  decq %rdi
  ret

right:
  incq %rdi
  ret

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
  movq $0, %rdi
  movq $1, %rdx
  syscall
  movq %rsi, %rdi
  ret
