# Tracing in Linux and MacOS

This repository contains code discussed in my 
[blog post](https://blog.xfbs.net/tracing-linux-macos).
Check out [the raw writeup](tracing-linux-macos.md), or try the examples
yourself.

## Trying the examples

Everything you need is in the `Makefile`. If you are on Linux, you can try the
examples with one of:

    $ make linux-strace
    $ make linux-ltrace

If you are on MacOS (or another platform that provides DTrace), you can try the
examples with one of:

    $ make macos-dtruss
    $ make macos-dtruss-ls
    $ make macos-dtrace-calls
    $ make macos-dtrace-strcmp
