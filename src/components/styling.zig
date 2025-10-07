const std = @import("std");
const rl = @import("raylib");

const transparent = rl.Color{
    .r = 0,
    .g = 0,
    .b = 0,
    .a = 0,
};

pub const Selector = enum(u16) {
    None = 0x00,
    Hover = 0x01,
    Active = 0x02,
    Focus = 0x04,

    pub fn toggle(self: Selector, tog: Selector) Selector {
        return @enumFromInt(@intFromEnum(self) ^ @intFromEnum(tog));
    }

    pub fn add(self: Selector, a: Selector) Selector {
        return @enumFromInt(@intFromEnum(self) | @intFromEnum(a));
    }

    pub fn remove(self: Selector, rem: Selector) Selector {
        return @enumFromInt(@intFromEnum(self) & ~@intFromEnum(rem));
    }

    pub fn hasSelector(self: Selector, match: Selector) bool {
        return @intFromEnum(self) & @intFromEnum(match) != 0;
    }
};

pub const Styling = struct {
    default: WithoutSelector = WithoutSelector{},
    onHover: OptionalStyling = OptionalStyling{},

    pub fn withSelector(self: Styling, selector: Selector) Styling {
        if (selector == .None) {
            return self;
        }

        if (selector.hasSelector(.Hover)) {
            return .{
                .default = self.default.merge(self.onHover),
            };
        }

        std.log.warn("Selector not implemented yet: {}\n", .{selector});

        return self;
    }

    pub fn background(self: Styling) rl.Color {
        return self.default.background;
    }

    pub fn bg(self: Styling) rl.Color {
        return self.default.background;
    }

    pub fn foreground(self: Styling) rl.Color {
        return self.default.color;
    }

    pub fn fg(self: Styling) rl.Color {
        return self.default.color;
    }

    pub fn color(self: Styling) rl.Color {
        return self.default.color;
    }

    pub fn border(self: Styling) Border {
        return self.default.border;
    }

    pub fn border_width(self: Styling) i32 {
        return self.default.border.width;
    }

    pub fn border_color(self: Styling) rl.Color {
        return self.default.border.color;
    }

    pub fn border_radius(self: Styling) i32 {
        return self.default.border.radius;
    }

    pub fn font_size(self: Styling) i32 {
        return self.default.font_size;
    }
};

pub const DynamicSize = union(enum) {
    Pixels: i32,
    Percent: f32,
};

pub const WithoutSelector = struct {
    background: rl.Color = transparent,
    color: rl.Color = rl.Color.black,

    x: ?i32 = null,
    y: ?i32 = null,
    height: ?DynamicSize = null,
    width: ?DynamicSize = null,

    padding: SideValue = .{ .All = 0 },
    margin: SideValue = .{ .All = 0 },
    gap: i32 = 0,

    direction: Direction = .Row,

    font_size: i32 = 18,

    border: Border = .{},

    pub fn merge(self: WithoutSelector, other: OptionalStyling) WithoutSelector {
        var result = self;

        if (other.background) |bg_| {
            result.background = bg_;
        }

        if (other.color) |color_| {
            result.color = color_;
        }

        if (other.border) |border_| {
            result.border = border_;
        }

        if (other.x) |x_| {
            result.x = x_;
        }

        if (other.y) |y_| {
            result.y = y_;
        }

        if (other.height) |height_| {
            result.height = height_;
        }

        if (other.width) |width_| {
            result.width = width_;
        }

        if (other.padding) |padding_| {
            result.padding = padding_;
        }

        if (other.margin) |margin_| {
            result.margin = margin_;
        }

        if (other.gap) |gap_| {
            result.gap = gap_;
        }

        if (other.direction) |direction_| {
            result.direction = direction_;
        }

        if (other.font_size) |font_size_| {
            result.font_size = font_size_;
        }

        return result;
    }
};

pub const OptionalStyling = struct {
    background: ?rl.Color = null,
    color: ?rl.Color = null,

    x: ?i32 = null,
    y: ?i32 = null,
    height: ?DynamicSize = null,
    width: ?DynamicSize = null,

    padding: ?SideValue = null,
    margin: ?SideValue = null,
    gap: ?i32 = null,

    direction: ?Direction = null,

    font_size: ?i32 = null,

    border: ?Border = null,
};

const Direction = enum { Row, Column };

pub const Border = struct {
    width: i32 = 1,
    color: rl.Color = rl.Color.black,
    radius: i32 = 0,
};

pub const Side = enum {
    Top,
    Right,
    Bottom,
    Left,
};

pub const SideValue = union(enum) {
    All: i32,
    Symmetric: struct {
        vertical: i32,
        horizontal: i32,
    },
    Single: struct {
        top: i32,
        right: i32,
        bottom: i32,
        left: i32,
    },

    pub fn value(self: SideValue) struct { top: i32, right: i32, bottom: i32, left: i32 } {
        return switch (self) {
            .All => |all| .{
                .top = all,
                .right = all,
                .bottom = all,
                .left = all,
            },
            .Symmetric => |sym| .{
                .top = sym.vertical,
                .right = sym.horizontal,
                .bottom = sym.vertical,
                .left = sym.horizontal,
            },
            .Single => |sng| .{
                .top = sng.top,
                .right = sng.right,
                .bottom = sng.bottom,
                .left = sng.left,
            },
        };
    }

    pub fn valueFloat(self: SideValue) struct { top: f32, right: f32, bottom: f32, left: f32 } {
        return switch (self) {
            .All => |all| .{
                .top = @floatFromInt(all),
                .right = @floatFromInt(all),
                .bottom = @floatFromInt(all),
                .left = @floatFromInt(all),
            },
            .Symmetric => |sym| .{
                .top = @floatFromInt(sym.vertical),
                .right = @floatFromInt(sym.horizontal),
                .bottom = @floatFromInt(sym.vertical),
                .left = @floatFromInt(sym.horizontal),
            },
            .Single => |sng| .{
                .top = @floatFromInt(sng.top),
                .right = @floatFromInt(sng.right),
                .bottom = @floatFromInt(sng.bottom),
                .left = @floatFromInt(sng.left),
            },
        };
    }
};
