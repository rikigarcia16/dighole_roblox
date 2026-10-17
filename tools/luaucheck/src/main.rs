use mlua::prelude::*;
use std::fs;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let mode = args.get(1).map(String::as_str).unwrap_or("check");
    let lua = Lua::new();
    let mut failed = false;
    match mode {
        "check" => {
            for f in &args[2..] {
                let src = fs::read_to_string(f).expect("read");
                match lua.load(&src).set_name(f.as_str()).into_function() {
                    Ok(_) => {}
                    Err(e) => { failed = true; eprintln!("SYNTAX {}: {}", f, e); }
                }
            }
        }
        "run" => {
            let g = lua.globals();
            let loadfile = lua.create_function(|l, path: String| {
                let src = fs::read_to_string(&path).map_err(|e| LuaError::external(format!("{}: {}", path, e)))?;
                l.load(&src).set_name(path.as_str()).into_function()
            }).unwrap();
            g.set("loadfile", loadfile).unwrap();
            // loadwrapped(path, header): compiles `header .. source` so injected names (script,
            // require, game...) are locals instead of a setfenv environment, which would disable
            // Luau's fast paths and distort benchmarks.
            let loadwrapped = lua.create_function(|l, (path, header): (String, String)| {
                let src = fs::read_to_string(&path).map_err(|e| LuaError::external(format!("{}: {}", path, e)))?;
                let full = format!("{} {}", header, src);
                l.load(&full).set_name(path.as_str()).into_function()
            }).unwrap();
            g.set("loadwrapped", loadwrapped).unwrap();
            let f = &args[2];
            let src = fs::read_to_string(f).expect("read");
            if let Err(e) = lua.load(&src).set_name(f.as_str()).exec() {
                failed = true; eprintln!("ERROR: {}", e);
            }
        }
        _ => {}
    }
    if failed { std::process::exit(1); }
}
