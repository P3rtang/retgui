const std = @import("std");

pub const State = struct {
    parent: *anyopaque,

    pub fn cast(self: *State, comptime T: type) *T {
        return @ptrCast(@alignCast(self.parent));
    }
};

pub fn StateValue(comptime T: type) type {
    return struct {
        const Self = @This();

        state: State,
        value: T,

        pub fn init(alloc: std.mem.Allocator, val: T) *Self {
            const self = alloc.create(Self) catch unreachable;

            self.* = Self{
                .state = State{ .parent = @ptrCast(@alignCast(self)) },
                .value = val,
            };

            return self;
        }

        pub fn get(state: *State) T {
            const self = state.cast(Self);
            return self.value;
        }

        pub fn set(state: *State, val: T) void {
            const self = state.cast(Self);
            self.value = val;
        }
    };
}
