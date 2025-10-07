const std = @import("std");
const EventLoop = @import("loop.zig").EventLoop;
const state = @import("state.zig");
const State = state.State;

pub fn StateEffect(comptime T: type) type {
    return struct {
        const Self = @This();

        effect: Effect,
        deps: []State,
        closure: T,

        pub fn init(callback: *const fn (*Effect, []State) void, deps: anytype) void {
            const self = EventLoop.alloc.create(Self) catch @panic("Out of memory");
            const deps_slice = &[_]State{deps.*};

            const effect = Effect{
                .callback = callback,
                .deinitFn = null,
            };

            self.* = Self{ .effect = effect, .deps = deps_slice };

            EventLoop.init().addEffect(&self.effect);
        }
    };
}

pub fn TaskEffect(comptime T: type, comptime Err: type) type {
    return struct {
        const Self = @This();
        const ITask = Task(T, Err);

        effect: Effect,
        task: *ITask,

        pub fn init(task: *ITask) void {
            const self = EventLoop.alloc.create(Self) catch @panic("Out of memory");

            const effect = Effect{
                .callback = &Self.resolve,
            };

            self.* = .{ .task = task, .effect = effect };

            EventLoop.init().addEffect(&self.effect);
        }

        pub fn resolve(effect: *Effect) void {
            const self = effect.cast(Self);

            switch (self.task.poll()) {
                .Resolved => {
                    self.effect.dirty = false;
                },
                .Failed => {
                    self.effect.dirty = false;
                },
                .Pending => {},
            }
        }
    };
}

pub const Effect = struct {
    callback: *const fn (*Effect) void,
    deinitFn: ?*const fn (*Effect) void = null,
    dirty: bool = true,

    pub fn deinit(self: *Effect) void {
        if (self.deinitFn) |deinit_fn| {
            deinit_fn(self);
        }
    }

    pub fn cast(self: *Effect, comptime T: type) *T {
        return @fieldParentPtr("effect", self);
    }
};

pub fn Task(comptime T: type, comptime Err: type) type {
    return struct {
        const Self = @This();

        const Result = union(enum) {
            Pending,
            Resolved: T,
            Failed: Err,
        };

        alloc: std.mem.Allocator,
        state: Result = .Pending,

        pollFn: ?*const fn (self: *Self) Result = null,

        pub fn init(alloc: std.mem.Allocator) Self {
            return Self{
                .alloc = alloc,
            };
        }

        pub fn resolved(value: T) Self {
            return Self{
                .alloc = std.heap.page_allocator,
                .state = .{ .Resolved = value },
            };
        }

        pub fn poll(self: *Self) Self.Result {
            if (self.pollFn) |poll_fn| {
                return poll_fn(self);
            }

            return self.state;
        }

        pub fn wait(self: *Self) Err!T {
            while (true) {
                switch (self.poll()) {
                    .Pending => std.Thread.sleep(10 * std.time.ns_per_ms),
                    .Resolved => |value| return value,
                    .Failed => |err| return err,
                }
            }
        }

        pub fn super(self: *Self, comptime U: type) *U {
            return @fieldParentPtr("task", self);
        }

        pub fn then(
            self: *Self,
            comptime U: type,
            comptime func: fn (T, anytype) Task(U, anyerror),
            closure: anytype,
        ) Chain(T, Err, U, func) {
            return Chain(T, Err, U, func).init(self, closure);
        }
    };
}

pub fn Chain(comptime T: type, comptime Err: type, comptime U: type, comptime func: fn (T, anytype) Task(U, anyerror)) type {
    return struct {
        const Self = @This();
        const PrevTask = Task(T, Err);
        const NextTask = Task(U, anyerror);

        comptime func: fn (T, anytype) NextTask = func,

        prev: *PrevTask,
        task: NextTask,

        prev_resolved: bool = false,
        closure: *anyopaque,

        pub fn init(prev: *PrevTask, closure: anytype) Self {
            var next_task = NextTask.init(prev.alloc);
            next_task.pollFn = &Self.poll;

            return Self{
                .prev = prev,
                .task = next_task,
                .closure = @ptrCast(@constCast(&closure)),
            };
        }

        pub fn poll(task: *NextTask) NextTask.Result {
            const self = task.super(Self);
            std.debug.print("Polling chain task...\n", .{});

            if (self.prev_resolved) {
                return self.task.poll();
            }

            const prev_state = self.prev.poll();

            switch (prev_state) {
                .Pending => return .Pending,
                .Failed => return .{ .Failed = prev_state.Failed },
                .Resolved => |value| {
                    self.prev_resolved = true;
                    self.task = self.func(value, self.closure);
                },
            }

            return self.task.poll();
        }
    };
}

pub const Fetch = struct {
    const Self = @This();

    const Error = anyerror;
    const ITask = Task([]const u8, Error);

    const Context = struct {
        alloc: std.mem.Allocator,
        url: []const u8,
        client: std.http.Client,
        writer: std.Io.Writer.Allocating,
        socket: ?std.posix.socket_t = null,
        request_sent: bool = false,
    };

    task: ITask,
    is_running: bool = false,
    context: Context,

    pub fn init(alloc: std.mem.Allocator, url: []const u8) !*Self {
        const client = std.http.Client{ .allocator = alloc };
        const writer = std.Io.Writer.Allocating.init(alloc);

        const task = ITask.init(alloc);
        const context = Context{ .alloc = alloc, .url = url, .client = client, .writer = writer };

        const self = alloc.create(Self) catch @panic("Out of memory");
        self.* = Self{ .task = task, .context = context };

        self.task.pollFn = &Self.poll;

        return self;
    }

    pub fn deinit(self: *Self) void {
        self.context.writer.deinit();
        self.context.client.deinit();
        self.task.deinit();
        self.context.alloc.destroy(self);
    }

    pub fn tryWait(self: *Self) Error!void {
        const ctx = &self.context;

        _ = try ctx.client.fetch(.{ .location = .{ .url = ctx.url }, .response_writer = &ctx.writer.writer });
    }

    pub fn wait(self: *Self) void {
        self.tryWait() catch |err| {
            self.task.state = .{ .Failed = err };
        };

        const slice = self.context.writer.toOwnedSlice() catch @panic("Out of memory");

        self.task.state = .{ .Resolved = slice };
    }

    pub fn poll(task: *ITask) ITask.Result {
        const self = task.super(Self);

        if (!self.is_running) {
            _ = std.Thread.spawn(.{}, Self.wait, .{self}) catch |err| {
                return .{ .Failed = err };
            };
        }

        return self.task.state;
    }
};
