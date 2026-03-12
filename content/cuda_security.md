
+++
title = "Cuda security"
date = 2026-01-09
[taxonomies]
tags = ["none"]
+++

Some notes on cuda
<!-- more -->

A promising area is to understand security vulnerabilities in CUDA applications. This includes understanding how to secure CUDA applications against common security threats such as buffer overflows, memory leaks, and race conditions. Additionally, it is important to understand how to secure CUDA applications against malicious actors who may attempt to exploit vulnerabilities in the application.

Two major security area is GPU kernel boundary between host and device. GPU kernel is inheritantly unsafe, an example: 

A natural solution is to use formal verification tool such VerCos. There is also another group attempt to use LLM to automatically generate gpu kernel while using formal verification tool to verify correctness of generated program.

However, beyond just the kernel, interaction between host and device also have security vulunabilities.

- Rust support for GPU ecosystem is [maturing](https://rust-gpu.github.io/blog/2025/07/25/rust-on-every-gpu)
- 

## Rust vs C++

Compare RustCuda to C++ same kernel and host program computing add.
