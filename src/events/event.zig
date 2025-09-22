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

pub fn Callback(comptime T: type) type {
    return struct {
        const Self = @This();

        closure: *T,
        func: *const fn (event: Event, component: *T) anyerror!bool,

        pub fn call(self: *Self, event: Event) anyerror!bool {
            return self.func(event, self.closure);
        }
    };
}
