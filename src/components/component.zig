const std = @import("std");
const rl = @import("raylib");
const time = @cImport({
    @cInclude("time.h");
});

const stl = @import("styling.zig");
const ev = @import("events");

pub const t = @import("tree.zig");

const Uid = t.Uid;

const Self = @This();

const EventKind = ev.EventKind;
const Callback = ev.Callback;

const Styling = stl.Styling;
const Selector = stl.Selector;

const getFontSize = @import("font.zig").getFontSize;

const LogLevel = enum {
    Info,
    Warn,
    Error,

    pub fn toString(self: LogLevel) []const u8 {
        return switch (self) {
            .Info => "INFO",
            .Warn => "WARN",
            .Error => "ERROR",
        };
    }
};

const DebugOptions = struct {
    severity: LogLevel = .Info,
    message: ?[]const u8 = null,
    loc: ?std.builtin.SourceLocation = null,
};

pub const Vector2Int = struct {
    x: i32 = 0,
    y: i32 = 0,
};

pub const Rectangle = struct {
    x: i32,
    y: i32,
    width: i32,
    height: i32,

    pub fn init(x: i32, y: i32, width_: i32, height_: i32) Rectangle {
        return Rectangle{
            .x = x,
            .y = y,
            .width = width_,
            .height = height_,
        };
    }

    pub fn from(rect: anytype) Rectangle {
        return Rectangle{
            .x = @intFromFloat(rect.x),
            .y = @intFromFloat(rect.y),
            .width = @intFromFloat(rect.width),
            .height = @intFromFloat(rect.height),
        };
    }

    pub fn intoRl(self: Rectangle) rl.Rectangle {
        return rl.Rectangle{
            .x = @floatFromInt(self.x),
            .y = @floatFromInt(self.y),
            .width = @floatFromInt(self.width),
            .height = @floatFromInt(self.height),
        };
    }
};

pub const Size = struct {
    width: i32,
    height: i32,
};

// TODO: remove the allocation here, it should all go through tree
alloc: std.mem.Allocator = std.heap.page_allocator,
uid: Uid,
super: ?*anyopaque = null,

selectors: Selector = .None,

children: std.ArrayList(*Self) = std.ArrayList(*Self).empty,

rect: Rectangle,
styling: Styling = Styling{},

deinitFn: ?*const fn (self: *Self) void = null,
drawFn: ?*const fn (self: *Self) anyerror!void = null,
setTextFn: ?*const fn (self: *Self, text: []const u8) void = null,
sizeFn: ?*const fn (self: *Self) Size = null,
childOffsetFn: ?*const fn (self: *Self, uid: Uid) Vector2Int = null,

eventListeners: std.AutoHashMapUnmanaged(EventKind, Callback) = std.AutoHashMapUnmanaged(EventKind, Callback).empty,

pub fn cast(self: *Self, comptime T: type) *T {
    return @fieldParentPtr("component", self);
}

pub fn init() Self {
    return Self{
        .uid = Uid.init(),
        .rect = Rectangle.init(0, 0, 0, 0),
        // .dispatchEventFn = props.dispatchEventFn,
    };
}

pub fn deinit(self: *Self, comptime T: type) void {
    if (self.deinitFn) |deinit_fn| {
        deinit_fn(self);
    }

    const self_ptr = self.cast(T);
    self.alloc.destroy(self_ptr);
}

pub fn debug(self: *Self, opts: DebugOptions) void {
    const tm = time.time(null);
    const tm_ptr = time.localtime(&tm);

    var buffer: [32]u8 = undefined;
    _ = time.strftime(&buffer, 32, "%Y-%m-%d %H.%M.%S", tm_ptr);
    _ = std.fmt.bufPrint(buffer[19..], "{:0>3}", .{@mod(std.time.milliTimestamp(), 1000)}) catch "";
    // do this later to replace the sign of the milliseconds string
    buffer[19] = '_';

    const fileLine = fl: {
        if (opts.loc) |loc| {
            break :fl std.fmt.allocPrint(self.alloc, "src/{s}/{s}:{}", .{ loc.module, loc.file, loc.line }) catch "";
        }

        break :fl "";
    };

    std.debug.print("{s}: {s} | {s} | Component {d}: {s}\n", .{
        fileLine,
        opts.severity.toString(),
        buffer[0..23],
        self.uid.id,
        opts.message orelse "",
    });
}

pub fn draw(self: *Self) !void {
    _ = try self.dispatchEvent(.Draw);

    try self.defaultDraw();

    if (self.drawFn) |drawFn| try drawFn(self);
}

pub fn defaultDraw(self: *Self) anyerror!void {
    const style = self.styling.withSelector(self.selectors);

    const rect = self.rectangle();
    const br: f32 = @floatFromInt(style.border_radius());

    rl.drawRectangleRounded(rect.intoRl(), br / rect.intoRl().height, 0, style.bg());
    // rl.drawRectangleRoundedLinesEx(rect.intoRl(), br / rect.intoRl().height, 0, 1.0, rl.Color.black);

    for (self.children.items) |child| {
        try child.draw();
    }
}

pub fn getChild(self: *const Self, uid: Uid) ?*Self {
    for (self.children.items) |child| {
        if (child.uid.id == uid.id) {
            return child;
        }
    }

    return null;
}

fn childOffset(self: *Self, uid: Uid) Vector2Int {
    if (self.childOffsetFn) |func| {
        return func(self, uid);
    }

    const styling = self.getStyling();
    const gap = styling.default.gap;
    const padding = styling.default.padding.value();
    const rect = self.rectangle();

    var offset = Vector2Int{ .x = rect.x + padding.left, .y = rect.y + padding.right };

    for (self.children.items) |child| {
        if (child.uid.id == uid.id) {
            return offset;
        }

        const size_ = child.size();

        switch (self.getStyling().default.direction) {
            .Row => {
                offset.x += size_.width + gap;
            },
            .Column => {
                offset.y += size_.height + gap;
            },
        }
    }

    return offset;
}

pub fn size(self: *Self) Size {
    if (self.sizeFn) |sizeFn| {
        return sizeFn(self);
    }

    return .{ .width = self.width(.{}), .height = self.height(.{}) };
}

pub fn fixedWidth(self: *Self) bool {
    return self.getStyling().default.width != null;
}

pub fn fixedHeight(self: *Self) bool {
    return self.getStyling().default.height != null;
}

const WidthOptions = struct { no_padding: bool = false };

pub fn width(self: *Self, opts: WidthOptions) i32 {
    if (self.sizeFn) |sizeFn| {
        return sizeFn(self).width;
    }

    const styling = self.getStyling();
    const padding = styling.default.padding.value();

    var w: i32 = 0;

    if (styling.default.width) |w_| {
        switch (w_) {
            .Percent => |p| {
                if (self.parent()) |parent_| {
                    const parent_width: f32 = @floatFromInt(parent_.width(.{ .no_padding = true }));
                    return @intFromFloat(parent_width * (p / 100.0));
                } else {
                    return self.rect.width;
                }
            },
            .Pixels => |p| {
                return p;
            },
        }
    }

    if (self.fixedWidth()) {
        return w;
    }

    for (self.children.items) |child| {
        if (child.fixedWidth()) {
            continue;
        }

        switch (styling.default.direction) {
            .Row => {
                w += @intCast(child.width(.{}));
            },
            .Column => {
                w = @max(w, child.width(.{}));
            },
        }
    }

    const len: i32 = @intCast(self.children.items.len);
    if (styling.default.direction == .Row) {
        w += @max(len - 1, 0) * styling.default.gap;
    }

    if (!opts.no_padding) {
        w += padding.left + padding.right;
    }

    return w;
}

pub fn height(self: *Self, opts: WidthOptions) i32 {
    if (self.sizeFn) |sizeFn| {
        return sizeFn(self).height;
    }

    const styling = self.getStyling();
    const padding = styling.default.padding.value();

    var h: i32 = 0;

    if (styling.default.height) |h_| {
        switch (h_) {
            .Percent => |p| {
                if (self.parent()) |parent_| {
                    const parent_height: f32 = @floatFromInt(parent_.height(.{ .no_padding = true }));
                    return @intFromFloat(parent_height * (p / 100.0));
                } else {
                    return self.rect.height;
                }
            },
            .Pixels => |p| {
                return p;
            },
        }
    }

    if (self.fixedHeight()) {
        return h;
    }

    for (self.children.items) |child| {
        if (child.fixedHeight()) {
            continue;
        }

        switch (styling.default.direction) {
            .Row => {
                h = @max(h, child.height(.{}));
            },
            .Column => {
                h += @intCast(child.height(.{}));
            },
        }
    }

    const len: i32 = @intCast(self.children.items.len);
    if (styling.default.direction == .Column) {
        h += @max(len - 1, 0) * styling.default.gap;
    }

    if (!opts.no_padding) {
        h += padding.top + padding.bottom;
    }

    return h;
}

pub fn rectangle(self: *Self) Rectangle {
    if (self.parent() == null) {
        return self.rect;
    }

    const styling = self.getStyling().default;

    const offset = self.parent().?.childOffset(self.uid);

    const x = x: {
        if (styling.x) |x| {
            break :x x;
        } else {
            break :x offset.x;
        }
    };

    const y = y: {
        if (styling.y) |y| {
            break :y y;
        } else {
            break :y offset.y;
        }
    };

    const size_ = self.size();

    return Rectangle{
        .x = x,
        .y = y,
        .width = size_.width,
        .height = size_.height,
    };
}

pub fn addChild(self: *Self, child: *Self) !void {
    try t.componentTree.?.addNode(self, child);

    try self.children.append(self.alloc, child);
}

pub fn onEvent(self: *Self, kind: EventKind, handler: Callback) !void {
    try self.eventListeners.put(self.alloc, kind, handler);
}

pub fn dispatchEvent(self: *Self, event: ev.Event) anyerror!bool {
    if (self.eventListeners.get(event.tag())) |handler| {
        var h = handler;
        return try h.call(event);
    }

    return true;
}

pub fn setText(self: *Self, text: []const u8) void {
    var rect = self.rectangle();
    const font_size = self.getStyling().font_size();
    const font = getFontSize(self.alloc, font_size);

    var null_terminated: [:0]u8 = self.alloc.allocSentinel(u8, text.len, 0) catch unreachable;
    std.mem.copyForwards(u8, null_terminated[0..text.len], text);

    const text_size = rl.measureTextEx(font, null_terminated, @floatFromInt(font_size), 2);

    rect.width = @intFromFloat(text_size.x);
    rect.height = @intFromFloat(text_size.y);

    self.setRectangle(rect);

    if (self.setTextFn) |setTextFn| {
        setTextFn(self, text);
    }
}

pub fn setRectangle(self: *Self, rect: Rectangle) void {
    self.rect = rect;
}

pub fn getState(self: *Self, comptime C: type, comptime T: type) ?*T {
    if (self.super) |sup| {
        const c: *C = @ptrCast(@alignCast(sup));
        return &c.state;
    }

    return null;
}

pub fn setState(self: *Self, comptime C: type, comptime T: type, state: T) void {
    if (self.super) |sup| {
        const c: *C = @ptrCast(@alignCast(sup));
        c.state = state;
    }
}

pub fn parent(self: *Self) ?*Self {
    if (t.componentTree == null) {
        return null;
    }

    const tree = t.componentTree.?;

    if (tree.nodes.getPtr(self.uid)) |node| {
        if (node.parent == null) {
            return null;
        }

        if (tree.nodes.getPtr(node.parent.?)) |parent_node| {
            return parent_node.component;
        }
    }

    return null;
}

pub fn getStyling(self: *Self) Styling {
    return self.styling.withSelector(self.selectors);
}
