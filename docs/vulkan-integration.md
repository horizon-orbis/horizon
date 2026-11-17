# Vulkan integration (Rust → RADV → VideoOut)

Findings from auditing the CyreneLauncher Orbis graphics stack
(`mesa-orbis`, `lwjgl-orbis` at the revisions pinned in `repositories.lock.json`).

## How Vulkan works on PS4 in this stack

1. **Driver**: Mesa is built for the PS4 with `HAVE_ORBIS_PLATFORM`; RADV runs on the
   NEO GPU profile (patches 0013/0016/0017/0019/0020/0021/0032/0033/0047/0048...).
   ACO compiles shaders natively for the console's GCN GPU.
2. **Loader**: there is no `libvulkan.so`. The platform PRX
   (`liborbis_lwjgl_platform.so`, built by `lwjgl-orbis/build_platform_prx.py`)
   **exports `vkGetInstanceProcAddr`** directly (`platform/orbis_vulkan.c`), wrapping
   `radv_GetInstanceProcAddr`. It also answers layer queries itself (empty layer list,
   VK_SUCCESS) — a quirk RADV alone would fail (VK_ERROR_LAYER_NOT_PRESENT).
3. **Surface**: created with `vkCreateHeadlessSurfaceEXT` (`VK_EXT_headless_surface`).
   The PRX helper `orbis_vulkan_create_surface()` does exactly this.
4. **Swapchain/presentation**: Mesa contains a full Orbis WSI platform
   (`src/vulkan/wsi/wsi_orbis.c`, ~950 lines) that hangs off the *headless* surface
   type. It implements standard `vkAcquireNextImageKHR` / `vkQueuePresentKHR` and
   presents with `sceVideoOutSubmitFlip` (VSync). Swapchain images are **linear**
   (`wsi_device.wants_linear = true`) because the display controller scans them out
   directly; zero-copy flips are used when the GPU renders into scanout buffers,
   otherwise one full-screen copy per frame. On host builds the Sony calls are
   stubbed (a flip "succeeds" showing nothing), so host tests exercise the same code
   path.
5. **Extras**: the PRX provides weak hooks `orbis_vulkan_scanout_state`,
   `orbis_vulkan_draw_pointer` (software cursor overlay between GPU wait and flip),
   and `orbis_vulkan_presentation_support`.

## What this means for wgpu (horizon-free)

- horizon-free vendors `third_party/wgpu-hal` (wgpu 30, Vulkan backend via `ash`).
- **ash entry point**: construct `ash::Entry` from the PRX's `vkGetInstanceProcAddr`
  instead of dlopen'ing `libvulkan.so` (ash supports custom entry loading; worst case
  we ship a tiny shim that forwards `vkGetInstanceProcAddr`/`vkEnumerateInstance*
  to the PRX export).
- **Instance extensions**: `VK_KHR_surface` + `VK_EXT_headless_surface` (same set
  Minecraft's Vulkan path uses; RADV supplies the rest).
- **Surface creation**: patch `wgpu-hal`'s Vulkan backend with an Orbis path that
  calls `vkCreateHeadlessSurfaceEXT` — everything downstream (swapchain config,
  acquire/queue/present) is generic Vulkan and works against `wsi_orbis` unchanged.
- **Feature requirements match**: wgpu 30 needs Vulkan 1.2 + dynamic rendering +
  push descriptors + synchronization2 — the same feature set Minecraft 26.3 requires,
  which the stack's acceptance probe already verifies on console.
- **winit is not involved**: no window system on PS4. The event loop and input come
  from the platform layer (DualSense via horizon-dualsense, keyboard/mouse via the
  console peripherals); presentation is the swapchain above.

## Build order (milestone 3)

1. Build Mesa for PS4 with the pinned kit (`mesa-orbis/orbis-port`, `build_mesa.py`,
   OpenOrbis SDK) → RADV + radeonsi archives + platform PRX.
2. Rust `vk-triangle` crate: `Entry` from PRX export → instance (headless ext) →
   device → swapchain → clear-color triangle → present ~600 frames.
3. On-console acceptance: same criteria as their Vulkan probe (loader identity,
   device/API string, extension/feature checks, 120+ presented frames).
4. Then port the same surface path into vendored `wgpu-hal` and run a wgpu clear.

## Open items

- How the standalone app loads the platform PRX (pkg `sce_module` LIBMODULES vs
  `orbis-runtime-support`'s `native_dlfcn`); the launcher's runner loads it for the
  JVM path — we replicate that for a native Rust app.
- Confirm `sceVideoOutOpen` user context (ORBIS_VIDEO_USER_MAIN) works for a native
  app rather than the JVM runner process.
- GL and Vulkan cannot own scanout simultaneously; our app is Vulkan-only, so this
  only matters if we later add a GL fallback.
