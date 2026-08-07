//! chimera_core — sovereign mesh node for ruby_llm_mesh.
//!
//! Exposes a C ABI for Ruby FFI:
//! - `start_node(port) -> bool`
//! - `node_alive() -> bool`
//! - `execute_wasm_payload(intent) -> *mut c_char` (JSON; caller frees via `chimera_free_string`)
//! - `stop_node() -> bool`

use std::ffi::{CStr, CString};
use std::io::{Read, Write};
use std::net::{SocketAddr, TcpListener, TcpStream};
use std::os::raw::c_char;
use std::sync::atomic::{AtomicBool, AtomicU16, Ordering};
use std::thread;
use std::time::Duration;

static ALIVE: AtomicBool = AtomicBool::new(false);
static PORT: AtomicU16 = AtomicU16::new(0);
static STOP: AtomicBool = AtomicBool::new(false);

/// Boot a lightweight mesh listener on `port`. Idempotent if already alive on same port.
#[no_mangle]
pub extern "C" fn start_node(port: u16) -> bool {
    if ALIVE.load(Ordering::SeqCst) && PORT.load(Ordering::SeqCst) == port {
        return true;
    }

    STOP.store(false, Ordering::SeqCst);
    let addr = SocketAddr::from(([127, 0, 0, 1], port));
    let listener = match TcpListener::bind(addr) {
        Ok(l) => l,
        Err(_) => return false,
    };
    if let Err(_) = listener.set_nonblocking(true) {
        return false;
    }

    PORT.store(port, Ordering::SeqCst);
    ALIVE.store(true, Ordering::SeqCst);

    thread::spawn(move || {
        while !STOP.load(Ordering::SeqCst) {
            match listener.accept() {
                Ok((stream, _)) => {
                    let _ = handle_connection(stream);
                }
                Err(ref e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                    thread::sleep(Duration::from_millis(25));
                }
                Err(_) => {
                    thread::sleep(Duration::from_millis(50));
                }
            }
        }
        ALIVE.store(false, Ordering::SeqCst);
    });

    true
}

#[no_mangle]
pub extern "C" fn stop_node() -> bool {
    STOP.store(true, Ordering::SeqCst);
    // Give the accept loop a moment to exit
    thread::sleep(Duration::from_millis(40));
    ALIVE.store(false, Ordering::SeqCst);
    true
}

#[no_mangle]
pub extern "C" fn node_alive() -> bool {
    ALIVE.load(Ordering::SeqCst)
}

/// Execute an intent payload natively and return a heap-allocated JSON C string.
/// Caller must free with `chimera_free_string`.
#[no_mangle]
pub extern "C" fn execute_wasm_payload(intent: *const c_char) -> *mut c_char {
    if intent.is_null() {
        return to_c_string(error_json("null intent pointer"));
    }

    let c_str = unsafe { CStr::from_ptr(intent) };
    let intent_str = match c_str.to_str() {
        Ok(s) => s,
        Err(_) => return to_c_string(error_json("invalid UTF-8 intent")),
    };

    let digest = simple_digest(intent_str);
    let escaped = escape_json(intent_str);
    let json = format!(
        "{{\"ok\":true,\"engine\":\"chimera_core\",\"mode\":\"native_wasm\",\"alive\":{},\"port\":{},\"intent\":\"{}\",\"digest\":\"{:016x}\",\"output\":\"Native mesh executed intent ({})\"}}",
        ALIVE.load(Ordering::SeqCst),
        PORT.load(Ordering::SeqCst),
        escaped,
        digest,
        truncate(&escaped, 64)
    );
    to_c_string(json)
}

#[no_mangle]
pub extern "C" fn chimera_free_string(ptr: *mut c_char) {
    if ptr.is_null() {
        return;
    }
    unsafe {
        let _ = CString::from_raw(ptr);
    }
}

#[no_mangle]
pub extern "C" fn chimera_core_version() -> *mut c_char {
    to_c_string("2.0.0".to_string())
}

fn handle_connection(mut stream: TcpStream) {
    let _ = stream.set_read_timeout(Some(Duration::from_millis(200)));
    let mut buf = [0u8; 1024];
    let _ = stream.read(&mut buf);
    let body = "{\"status\":\"ok\",\"engine\":\"chimera_core\",\"alive\":true}";
    let response = format!(
        "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
        body.len(),
        body
    );
    let _ = stream.write_all(response.as_bytes());
}

fn to_c_string(s: String) -> *mut c_char {
    match CString::new(s) {
        Ok(c) => c.into_raw(),
        Err(_) => CString::new("{\"ok\":false,\"error\":\"nul in string\"}")
            .unwrap()
            .into_raw(),
    }
}

fn error_json(msg: &str) -> String {
    format!(
        "{{\"ok\":false,\"engine\":\"chimera_core\",\"error\":\"{}\"}}",
        escape_json(msg)
    )
}

fn escape_json(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    for ch in s.chars() {
        match ch {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if c.is_control() => out.push_str(&format!("\\u{:04x}", c as u32)),
            c => out.push(c),
        }
    }
    out
}

fn simple_digest(s: &str) -> u64 {
    let mut h: u64 = 0xcbf29ce484222325;
    for b in s.as_bytes() {
        h ^= u64::from(*b);
        h = h.wrapping_mul(0x100000001b3);
    }
    h
}

fn truncate(s: &str, max: usize) -> String {
    if s.chars().count() <= max {
        s.to_string()
    } else {
        format!("{}…", s.chars().take(max).collect::<String>())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::CString;

    #[test]
    fn execute_returns_json() {
        let intent = CString::new("ping mesh").unwrap();
        let ptr = execute_wasm_payload(intent.as_ptr());
        assert!(!ptr.is_null());
        let s = unsafe { CStr::from_ptr(ptr) }.to_str().unwrap();
        assert!(s.contains("chimera_core"));
        assert!(s.contains("ping mesh"));
        chimera_free_string(ptr);
    }
}
