# patch command line tool (C++ port)

Produces binary patches in the bipatch + zstd wire format consumed by the updater's `inflate_patch`.

## Usage

    patch <base> <new> <output>

    string_patch <base> <new>

## Build

Built as a subdirectory of the parent `updater/` CMake project:

```bash
cd ../
cmake -S . -B cmake-build-debug
cmake --build cmake-build-debug --target patch string_patch
./cmake-build-debug/patch/patch old new patch.bin
./cmake-build-debug/patch/string_patch foo bar
```

## Algorithm

Implements Colin Percival's [bsdiff] (2003) — suffix-array based binary
matching with bsdiff's fuzzy forward/backward extension heuristic. Output
bytes differ from the upstream Rust `bidiff` crate even on identical input
because the two algorithms make different greedy choices, but the wire
format is byte-equivalent: patches produced here are accepted unchanged
by `dashpod::core::inflate_patch`. The round-trip is covered by
`updater/tests/test_patch.cpp`.

For very large inputs (≳50 MB) the `std::sort`-based suffix array will be
the dominant cost. A future revision can swap in SA-IS / libdivsufsort
without changing the wire format.

[bsdiff]: http://www.daemonology.net/bsdiff/

## Generating test expectations

The `string_patch` target prints the same fields as the upstream Rust
binary, in the same order:

```
% ./string_patch foo bar
Base: foo
New: bar
Patch: [40, 181, 47, 253, ...]
Hash (new): fcde2b2edba56bf408601fb721fe9b5c338d10ee429ea04fae5511b68fbf8fb9
```

The patch bytes will not be identical to the Rust output (different
algorithm), but applying either patch with `inflate_patch` produces the
same result.
