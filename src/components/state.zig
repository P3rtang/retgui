const std = @import("std");
const rl = @import("raylib");
const Component = @import("component.zig");

pub fn withState(comptime T: type, comptime State: type) type {
    return struct {
        const Self = @This();

        state: State,

        pub fn init(conf: T.Props) *Component {
            const comp = T.init(conf);

            const self = conf.alloc.create(Self) catch unreachable;

            self.* = Self{
                .state = undefined,
            };

            comp.super = @ptrCast(@alignCast(self));

            return comp;
        }

        fn getState(self: *Self) *State {
            return &self.state;
        }

        fn setState(self: *Self, newState: State) void {
            self.state = newState;
        }
    };
}
