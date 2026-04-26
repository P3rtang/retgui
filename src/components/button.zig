const std = @import("std");
const rl = @import("raylib");
const Component = @import("component.zig");
const State = @import("events").StateValue(anyopaque);

const Self = @This();

component: Component,

pub fn init(_: anytype) Self {
    const component = Component.init();

    return .{ .component = component };
}
