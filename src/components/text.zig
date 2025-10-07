const std = @import("std");
const rl = @import("raylib");
const Component = @import("component.zig");
const State = @import("events").StateValue([]const u8);

const getFontSize = @import("font.zig").getFontSize;

const Self = @This();

component: Component,
content: *State,
super: *anyopaque = undefined,

pub fn init(props: anytype) Self {
    var component = Component.init();
    component.deinitFn = &Self.deinit;
    component.drawFn = &Self.draw;
    component.setTextFn = &Self.setText;
    component.sizeFn = &Self.size;

    return Self{
        .component = component,
        .content = State.init(component.alloc, @field(props, "content")),
    };
}

pub fn deinit(comp: *Component) void {
    const self = comp.cast(Self);
    comp.alloc.destroy(self.content);
}

pub fn draw(this: *Component) !void {
    const self = this.cast(Self);

    const styling = this.styling.withSelector(this.selectors);
    const font_size = styling.font_size();
    const font = getFontSize(this.alloc, font_size);

    const content = State.get(&self.content.state);
    var null_terminated: [:0]u8 = this.alloc.allocSentinel(u8, content.len, 0) catch unreachable;
    std.mem.copyForwards(u8, null_terminated[0..content.len], content);

    const parent_rect = this.parent().?.rectangle();
    const text_size = rl.measureTextEx(font, null_terminated, @floatFromInt(font_size), 2);

    const width_f: f32 = @floatFromInt(parent_rect.width);
    const height_f: f32 = @floatFromInt(parent_rect.height);

    const x_f: f32 = @floatFromInt(parent_rect.x);
    const y_f: f32 = @floatFromInt(parent_rect.y);

    const pos = rl.Vector2{
        .x = x_f + (width_f - text_size.x) / 2,
        .y = y_f + (height_f - text_size.y) / 2,
    };

    rl.drawTextEx(font, null_terminated, pos, @floatFromInt(font_size), 2, rl.Color.black);
}

pub fn setText(this: *Component, text: []const u8) void {
    const self = this.cast(Self);
    State.set(&self.content.state, text);
}

fn size(comp: *Component) Component.Size {
    const self = comp.cast(Self);

    const content = State.get(&self.content.state);

    const styling = comp.styling.withSelector(comp.selectors);
    const font_size = styling.font_size();
    const font = getFontSize(comp.alloc, font_size);

    var null_terminated: [:0]u8 = comp.alloc.allocSentinel(u8, content.len, 0) catch unreachable;
    std.mem.copyForwards(u8, null_terminated[0..content.len], content);

    const s = rl.measureTextEx(font, null_terminated, @floatFromInt(font_size), 2);

    return .{ .height = @intFromFloat(s.y), .width = @intFromFloat(s.x) };
}
