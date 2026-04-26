const std = @import("std");

pub const EventKind = enum {
    Draw,
    MouseMove,
    MouseLeftDown,
    MouseRightDown,
    MouseLeftPress,
    MouseRightPress,
    KeyPress,
};

pub const Event = union(EventKind) {
    Draw,
    MouseMove: struct {
        x: i32,
        y: i32,
    },
    MouseLeftDown: struct {
        x: i32,
        y: i32,
    },
    MouseRightDown: struct {
        x: i32,
        y: i32,
    },
    MouseLeftPress: struct {
        x: i32,
        y: i32,
    },
    MouseRightPress: struct {
        x: i32,
        y: i32,
    },
    KeyPress: struct {
        key: u32,
    },

    pub fn tag(self: Event) EventKind {
        switch (self) {
            .Draw => return .Draw,
            .MouseMove => return .MouseMove,
            .MouseLeftDown => return .MouseLeftDown,
            .MouseRightDown => return .MouseRightDown,
            .MouseLeftPress => return .MouseLeftPress,
            .MouseRightPress => return .MouseRightPress,
            .KeyPress => return .KeyPress,
        }
    }
};

pub const Callback = struct {
    const Self = @This();

    closureFn: *const fn (*Callback) *anyopaque,
    func: *const fn (*Callback, Event, *anyopaque) anyerror!bool,
    super: *anyopaque,

    pub fn call(self: *Self, event: Event) anyerror!bool {
        const closure = self.closureFn(self);

        return self.func(self, event, closure);
    }

    pub fn cast(c: *Callback, comptime T: type) *T {
        return @ptrCast(@alignCast(c.super));
    }
};

pub fn OnEvent(comptime Closure: type) type {
    return struct {
        const Self = @This();

        alloc: std.mem.Allocator,
        closure: *Closure,
        func: *const fn (*Closure) anyerror!bool,

        pub fn init(alloc: std.mem.Allocator, func: *const fn (*Closure) anyerror!bool, closure: Closure) Callback {
            const closure_ptr = alloc.create(Closure) catch @panic("Out of memory");
            closure_ptr.* = closure;

            const onEvent = alloc.create(Self) catch @panic("Out of memory");
            onEvent.* = .{ .alloc = alloc, .closure = closure_ptr, .func = func };

            return Callback{
                .closureFn = closureFn,
                .func = callbackFn,
                .super = onEvent,
            };
        }

        fn callbackFn(c: *Callback, _: Event, closure: *anyopaque) anyerror!bool {
            const self = c.cast(Self);
            return self.func(@ptrCast(@alignCast(closure)));
        }

        fn closureFn(c: *Callback) *anyopaque {
            const self = c.cast(Self);
            return @ptrCast(@alignCast(self.closure));
        }
    };
}
