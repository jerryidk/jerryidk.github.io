+++
title = "Some"
date = 2026-01-09
draft = true
+++

# Linux memory allocator design 

As a operating system, memory allocation is at the core its logic (~loc). Memory allocator not only needs to be able to provide various size and lifetime of allocation, but also needs to deal with modern highly multi-threaded cpus. 

Overall, to be a production-ready allocator, 
it requires

- performance
	1. concurrency (e.g. allocator needs to multi-threaded, and support numa)
	2. flexibility (e.g. map both virtual and physical contiguous memory to 
	combat against fragementation, support for different hardware memory, 
	sypport for different size allocation)
- security (e.g. temporal safety, mitiagtion of uaf and df alike bug)

To give a concrete example, a typical driver in kernel will need to
allocate small memory

This guide focuses on concurrency, more specifically, the design of linux 
memory allocator that made their allocator multi-threaded, and the various 
tricks they use to satisfy those requirement. 

# high interface

- kmalloc
Allocate contiguous physical memory and virtual memory
- vmalloc
Allocate contiguous virtual memory but physical memory need no
- mmap

A table

| Interface | Physically contiguous ? | Virtually contiguous ? |
| kmalloc | yes | yes |
| vmalloc | no  | yes | 

# Allocator diagram

```
vmalloc -- pagetable 
   |
kmalloc
   |
	Slab
   |
  Buddy
```

# kmalloc

Kmalloc is consists of two allocators a slab(slub/slob) allocator
that allocates for small objects and a buddy allocator that manages 
physical memory.

# Buddy (large, >= page sized allocation)

One of important issue physical memory allocator needs to take considerationis NUMA. In order to represent uniform access, physical memory is divided
into node `pg_data_t` that contains an array of zone `struct zone`.

```
Each struct zone contains an array of free lists for each page order size in
the struct free_area struct zone->free_area[MAX_ORDER] field protected by the
spinlock_t lock field.
```

Note that this lock is per zone! Meaning multiple cpu within allocating 
on that same zone will contend. Thus a per cpu data structure is provided.
```
Aside from the core free lists there is an additional ‘cache’ of per-CPU
free lists for pages of lower orders to allow efficient allocation without
acquiring a lock to do so, stored in struct per_cpu_pages objects in the
struct zone->per_cpu_pageset field. 
```

There is a lock within `struct per_cpu_pages`, 
that will be used to access the this pcp. This data structure 
is accessed per cpu, so lock is used to disable interrupt.
https://elixir.bootlin.com/linux/v6.18.6/source/mm/page_alloc.c#L3280

# Slab (small, < page sized allocation)
 
Kernel often needs a small allocation for example, a driver
Key data structures

strcut kmem_cache
	-> struct kmem_cache_cpu (per cpu cache, similar to pcp)
  -> strcut kmem_cache_node (per node)

# Issue

Now it seems like we have solved most of the issues
we can allocate various size of objects. Everything is good, but 
consider following pattern where full memory address space is 

0x0 - 0x3FFF

and 0x1000, 0x3000 in use. and user wants to request a 8k (2pages)
memory. We have enough physical memory, but we can't allocate because
we can't return user a pointer at 0x0 because user will happily override
0x1000. 

This is known as memory fragmentation. Now, to solve this, we need 
virtual memory. 

pagetable maps a virtual page into physical page. 
By manipulating pagetable, this enables us to map vp#n -> 0x0
and vp#n+1 -> 0x2000 and return vpn as a contiguous allocation 
to user, thus solving the fragmentation issue. 
	
TLB shootdown ?

# Kernel address mapping
In order to understand vmalloc, we need to understand the va to pa mapping of kernel memory. Okay kmalloc doesn't really directly return user 
physical address, it returns user a virtual address 
that is shifted. 

vmalloc allocates memory that is not necessarily physically 
contiguous. This means, it requires communication of with 
physical memory allocator to ensure that the same 
physical memory is not handed out multiple times. 

The tricks here is to create separate va range for vmalloc 
to manages. This in practice means that you can see if an allocation 
is from kmalloc and vmalloc by simply observing which pointer value 
itself in kernel.  

# vmalloc

High level: 

vmalloc manages virtual address at VM_RANGE_START to END in kernel. 

Upon allocation, it needs to 

1. find free ranges in kernel virtual address (continuous)
2. find free physical pages from buddy (no need for continous, just page)
3. maps vpn to ppn by changing kernel pagetable `init_mm->pdg`

