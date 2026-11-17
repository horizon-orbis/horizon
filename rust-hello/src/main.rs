#![no_std]
#![no_main]

use core::arch::asm;
use core::panic::PanicInfo;

extern "C" {
    fn printf(fmt: *const u8, ...) -> i32;
    fn sceKernelDebugOutText(dbg_channel: i32, text: *const u8) -> i32;
    fn sceKernelUsleep(micros: u32) -> i32;
    fn fopen(path: *const u8, mode: *const u8) -> *mut u8;
    fn fwrite(ptr: *const u8, size: usize, nmemb: usize, stream: *mut u8) -> usize;
    fn fclose(stream: *mut u8) -> i32;
}

static HELLO: &[u8] = b"Hello from Rust on PS4!\n\0";
static DONE: &[u8] = b"Rust main returned, looping forever...\n\0";
static MARK_PATH: &[u8] = b"/data/rust_hello.txt\0";
static MARK_MODE: &[u8] = b"w\0";
static MARK_TEXT: &[u8] = b"Rust on PS4 works!\n\0";

#[no_mangle]
extern "C" fn main(_argc: i32, _argv: *const *const u8) -> i32 {
    unsafe {
        sceKernelDebugOutText(0, HELLO.as_ptr());
        printf(b"rust printf: %d + %d = %d\n\0".as_ptr(), 2i32, 40i32, 42i32);

        let f = fopen(MARK_PATH.as_ptr(), MARK_MODE.as_ptr());
        if !f.is_null() {
            fwrite(MARK_TEXT.as_ptr(), 1, MARK_TEXT.len() - 1, f);
            fclose(f);
            printf(b"wrote %s\n\0".as_ptr(), MARK_PATH.as_ptr());
        } else {
            printf(b"fopen failed for %s\n\0".as_ptr(), MARK_PATH.as_ptr());
        }

        sceKernelUsleep(2_000_000);
        sceKernelDebugOutText(0, DONE.as_ptr());
    }
    loop {
        unsafe { asm!("pause") }
    }
}

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {
        unsafe { asm!("pause") }
    }
}
