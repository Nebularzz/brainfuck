~THIS IS SO BAD :(((((~ THIS IS NO LONGER BAD!!!!
compile brainfuck for x86_64 linux wow!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

# Installation steps
1. Start by cloning the repository
```bash
git clone https://github.com/Nebularzz/brainfuck.git
```
2. Navigate into the repository
```bash
cd brainfuck
```
3. Build the app, the compiled binary should be in `zig-out/bin`
```bash
zig build --release=safe
```

# Compiling Brainfuck programs
The program only outputs the assembly instructions for your Brainfuck program, and does not assemble, nor link anything.
Therefore, a good way to build a Brainfuck program is to redirect the assembly to a file, then assemble it, and then link it.
This compiler in particular outputs assembly instructions that use the GNU Assemblers syntax.
```bash
/path/to/brainfuck main.bf > main.asm && as main.asm -o main.o && ld main.o -o main
```
