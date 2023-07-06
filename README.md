# zcauchemar

zcauchemar is an implementation of cauchemar, a stack-based programming
language inspired by [FORTH] but more arcane. 

[FORTH]: https://en.wikipedia.org/wiki/Forth_(programming_language)

- Emulates the look and feel of a programming language from the 60s to early 70s.
- Lacks variables and registers.
- Single global stack which stores 32-bit signed integers and booleans.
- No side-effects, can only print values to a terminal.
- No Read-Eval-Print-Loop.

```cauchemar
PROGRAM:
  "Hello, world!" PRINT       ; Display "Hello, world!"
  16 32 + 4 2 * /             ; Calculate (16 + 32) / (4 * 2)
  DUP PRINT                   ; Print the result
  DUP 6 EQUALS ASSERT         ; Validate the result
  PLUS-FORTY-TWO              ; Call routine "PLUS-FORTY-TWO"
  
  DUP 50 GREATER-THAN         ; Check if the result is greater than 50
  IF   "This is wrong" PRINT
  ELSE "This is right" PRINT
  THEN
  
  DO 1 -                      ; Count down to 0
     DUP PRINT 
     DUP 0 GREATER-THAN 
  WHILE
  
  DROP                        ; Reject the top of the stack


PLUS-FORTY-TWO:
  42 +                        ; Add 42 to the top of the stack
```

zcauchemar is the successor to the [original implementation] in [Rust].

[original implementation]: https://github.com/yukiisbored/cauchemar
[Rust]: https://www.rust-lang.org/

## Planned features

- Runtime-allocated Strings
- User input ("Requests")
- General value containers for long-live variables ("Blocks")
- Human-readable errors
  - List source code on stacktrace instead of VM instructions
- Extensive standard library
  - Math routines
  - String routines
  - Stack manipulation routines
  - Terminal IO routines
- Interactive session
  - Hopefully runs within the web browser for accessibility

## Frequently Asked Questions (F.A.Q)

### Why did you make this?

This programming language came from my dreams and it left a mark on me.

I thought it would be funny to make a real.

At the same time, I feel like it's quite interesting to explore a stack-based
programming language and roleplay as if we're in some "false-past" of early 
computing, akin to the world building you find in [Zachtronics] games.

[Zachtronics]: https://www.zachtronics.com

Today, stack-based computing takes a more background role as they're still
widely-used as the basis of many virtual machines for a garden variety of
programming languages or computing environments (i.e. [WebAssembly], [JVM],
[CPython], [CLR]). 

[WebAssembly]: https://en.wikipedia.org/wiki/WebAssembly
[JVM]: https://en.wikipedia.org/wiki/Java_virtual_machine
[CPython]: https://en.wikipedia.org/wiki/CPython
[CLR]: https://en.wikipedia.org/wiki/Common_Language_Runtime

### What does the name mean?

"Cauchemar" is the French word for "Nightmare" which is the origin of the
programming language.

### How do you pronounce the name?

This section is left as an excercise for the reader.

### Can I use this on production?

No, that's silly.

### Why did you reimplement this in Zig?

I originally wrote Cauchemar as an exercise to learn Rust.

At the end, while I'm happy that I got something nice to show to people,
I personally find Rust to be uncomfortable.

While I could spend time writing down the reasons why, I find that to be 
unproductive since ultimately, this is a personal opinion based on my
experience.

If you want a written explanation, see [Why Zig When There is Already C++, D, and Rust?].

[Why Zig When There is Already C++, D, and Rust?]: https://ziglang.org/learn/why_zig_rust_d_cpp/

Either way, I looked for alternatives, found Zig, and did this to learn it.

By the end, I'm met with a new implementation that is 7x faster than the original:

Rust (`cargo build -r`):

```console
$ hyperfine -N --warmup 24 './target/release/cauchemar ./examples/fib.cauchemar'
Benchmark 1: ./target/release/cauchemar ./examples/fib.cauchemar
  Time (mean ± σ):      43.6 ms ±   0.7 ms    [User: 42.2 ms, System: 0.7 ms]
  Range (min … max):    41.2 ms …  45.6 ms    68 runs
```

Zig (`zig build -Doptimize=ReleaseSafe`):

```console
$ hyperfine -N --warmup 24 './zig-out/bin/zcauchemar ./examples/fib.cauchemar'
Benchmark 1: ./zig-out/bin/zcauchemar ./examples/fib.cauchemar
  Time (mean ± σ):       6.0 ms ±   0.3 ms    [User: 5.1 ms, System: 0.5 ms]
  Range (min … max):     5.6 ms …   7.3 ms    520 runs
```

I acknowledge that my implementation in Rust isn't the best (in fact, I think 
it's really bad) but for both, it's my first implementation of cauchemar as an
exercise to learn the language. In a way, both are my first "Hello, world!"
program for both Zig and Rust.

So, as a result, I'm pretty happy with Zig and will continue using it in the
forseeable future.