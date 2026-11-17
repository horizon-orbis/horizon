# horizon — PS4 port project

Target: run [horizon-free](https://github.com/0CYBER/horizon-free) (Rust Minecraft
rewrite, wgpu 30) on a jailbroken PS4, rendering through **Vulkan** (RADV from the
CyreneLauncher Orbis Mesa stack), built with the
[OpenOrbis PS4 Toolchain](https://github.com/OpenOrbis/OpenOrbis-PS4-Toolchain).

## Current milestone: Rust on PS4 ✅

`rust-hello/` proves the critical path: a `no_std` Rust binary cross-compiled with a
custom rustc target (`x86_64-pc-freebsd12-elf`), linked against OpenOrbis musl/libkernel,
converted with `create-fself`, packaged into an installable PKG.

**Ready-to-install test package:** [`artifacts/IV0000-RUST00001_00-PS4RUSTHELLO0001.pkg`](artifacts/IV0000-RUST00001_00-PS4RUSTHELLO0001.pkg)

Install it with your homebrew package installer, launch **PS4 Rust Hello**, then
verify via FTP that `/data/rust_hello.txt` exists (contains "Rust on PS4 works!").
Nothing shows on screen yet — VideoOut arrives with the Vulkan milestone.

## Layout

| Path | Contents |
| --- | --- |
| `rust-hello/` | no_std Rust crate + custom target spec `ps4.json` |
| `scripts/setup-toolchain.sh` | one-shot user-local toolchain setup (SDK + clang 19 + lld) |
| `scripts/build-rust-hello.sh` | full rebuild: cargo → ld.lld → fself → PKG |
| `BUILD_NOTES.md` | environment details, gotchas, Vulkan port plan |

## Reproduce from scratch

```sh
./scripts/setup-toolchain.sh ~/ps4-dev
source ~/ps4-dev/env.sh
rustup toolchain install nightly --profile minimal --component rust-src
./scripts/build-rust-hello.sh
```

## Roadmap

1. ✅ OpenOrbis toolchain working (C++ sample)
2. ✅ Rust → PS4 ELF → eboot.bin → PKG
3. ⬜ Rust Vulkan triangle via RADV + platform PRX (headless surface + VideoOut)
4. ⬜ wgpu-hal patched for PS4 Vulkan (vendored in horizon-free)
5. ⬜ horizon-free platform layer: input (DualSense), audio (openal-soft-orbis), filesystem
6. ⬜ Full game boot + PKG packaging
