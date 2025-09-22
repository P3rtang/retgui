const std = @import("std");
const rl = @import("raylib");

const font_path = "./ComicMono.ttf";

pub const FontMap = std.AutoHashMapUnmanaged(i32, rl.Font);

pub var font: FontMap = std.AutoHashMapUnmanaged(i32, rl.Font).empty;

pub fn getFontSize(alloc: std.mem.Allocator, size: i32) rl.Font {
    if (font.get(size)) |f| {
        return f;
    } else {
        const f = rl.loadFontEx(font_path, size, null) catch @panic("Failed to load font");
        font.put(alloc, size, f) catch @panic("Out of memory");
        return f;
    }
}
