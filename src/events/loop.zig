const std = @import("std");
const rl = @import("raylib");

const Effect = @import("effect.zig").Effect;

var global_event_loop: ?EventLoop = null;

pub const EventLoop = struct {
    pub var alloc = std.heap.page_allocator;

    effects: std.ArrayList(*Effect) = std.ArrayList(*Effect).empty,

    pub fn init() *EventLoop {
        const self = EventLoop{};

        if (global_event_loop == null) {
            global_event_loop = self;
        }

        return &global_event_loop.?;
    }

    pub fn deinit(self: *EventLoop) void {
        for (self.effects.items) |*effect| {
            effect.deinit();
        }

        self.effects.deinit();
    }

    pub fn eval(self: *EventLoop) bool {
        var isDirty = false;

        for (self.effects.items) |effect| {
            if (effect.dirty) {
                effect.callback(effect);
                isDirty = true;
            }
        }

        return isDirty;
    }

    pub fn addEffect(self: *EventLoop, effect: *Effect) void {
        self.effects.append(alloc, effect) catch @panic("Out of memory");
    }
};
