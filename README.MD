# Brainfuck interpreter and JIT

A small Brainfuck interpreter and JIT implementation, loosly based on
[Eli Benderskys series](https://eli.thegreenplace.net/2017/adventures-in-jit-compilation-part-1-an-interpreter/)
on the topic. However, I choose to diverge here and there from the implementation.

Built with Zig version 0.13.0, usage:

```bash
zig build run -- -j -o test/test_mandelbrot.bf
```

