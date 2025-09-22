const std = @import("std");
const rl = @import("raylib");
const Component = @import("component.zig");

const getFontSize = @import("font.zig").getFontSize;

const Self = @This();

pub const Props = struct {
    alloc: std.mem.Allocator,
    content: []const u8,
};

component: Component,
content: []const u8,

pub fn init(props: Props) *Component {
    var component = Component.init(.{ .alloc = props.alloc });
    component.drawFn = &Self.draw;
    component.setTextFn = &Self.setText;

    component.setText(props.content);

    const self = props.alloc.create(Self) catch unreachable;

    self.* = Self{
        .component = component,
        .content = props.content,
    };

    return &self.component;
}

pub fn draw(this: *Component) !void {
    const self = this.cast(Self);

    const styling = this.styling.withSelector(this.selectors);
    const font_size = styling.font_size();
    const font = getFontSize(this.alloc, font_size);

    var null_terminated: [:0]u8 = this.alloc.allocSentinel(u8, self.content.len, 0) catch unreachable;
    std.mem.copyForwards(u8, null_terminated[0..self.content.len], self.content);

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

    std.debug.print("Drawing text: {s} at ({}, {})\n", .{ self.content, pos.x, pos.y });
    rl.drawTextEx(font, null_terminated, pos, @floatFromInt(font_size), 2, rl.Color.black);
}

pub fn setText(this: *Component, text: []const u8) void {
    const self = this.cast(Self);
    self.content = text;
}
