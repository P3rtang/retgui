const std = @import("std");

const components = @import("components");
const Text = components.Text;
const ButtonC = components.Button;
const Component = components.Component;
const ComponentTree = components.ComponentTree;
const Rectangle = components.Rectangle;
const withState = components.withState;
const Grid = components.Grid;
const ev = @import("events");
const EventLoop = ev.EventLoop;
const Effect = ev.Effect;
const StateEffect = ev.StateEffect;
const TaskEffect = ev.TaskEffect;
const Task = ev.Task;
const State = ev.State;
const Chain = ev.Chain;
const f = @import("components").font;
const getFontSize = f.getFontSize;
const retgui = @import("retgui");
const rl = @import("raylib");

const CONFIG_FLAGS = rl.ConfigFlags{
    .msaa_4x_hint = true,
    .window_resizable = false,
};

const STDIO = std.fs.File.stdout();

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    rl.setConfigFlags(CONFIG_FLAGS);
    rl.initWindow(800, 600, "retgui - example");

    const window = Window.init(alloc);
    defer window.deinit(Window);

    const body = Component.t.createNode(Box, .{});

    body.styling = .{
        .default = .{
            .padding = .{ .All = 16 },
            .gap = 16,
            .direction = .Column,
        },
    };

    try window.addChild(body);

    var button = Button(u32).init(.{ .alloc = alloc });
    defer button.deinit(Button(u32));
    button.setState(Button(u32), 0);

    try button.onEvent(.MouseLeftPress, *Component, struct {
        pub fn call(closure: **Component) anyerror!bool {
            closure.*.getState(Button(u32), u32).?.* += 1;
            return true;
        }
    }.call, button);

    button.styling = .{
        .default = .{
            .background = rl.Color.green,
            .border = .{
                .radius = 12,
            },
            .padding = .{ .Symmetric = .{ .vertical = 24, .horizontal = 48 } },
        },
        .onHover = .{
            .background = rl.Color.red,
        },
    };

    const button_text = Component.t.createNode(Text, .{ .content = "Click me!" });
    defer button_text.deinit(Text);

    const counter_box = Component.t.createNode(Box, .{});

    try body.addChild(counter_box);
    try body.addChild(button);
    try button.addChild(button_text);

    counter_box.styling = .{
        .default = .{
            .background = rl.Color.alpha(rl.Color.light_gray, 0.5),
            .border = .{
                .radius = 12,
            },
            .width = .{ .Percent = 100 },
            .padding = .{ .Symmetric = .{ .vertical = 24, .horizontal = 32 } },
        },
    };

    const CounterText = withState(Text, *Component);

    const counter_text = CounterText.init(.{ .alloc = alloc, .content = "0" });
    defer counter_text.deinit(Text);

    try counter_box.addChild(counter_text);
    counter_text.setState(CounterText, button);

    try counter_text.onEvent(.Draw, *Component, struct {
        pub fn call(closure: **Component) anyerror!bool {
            const count = closure.*.getState(CounterText, *Component).?.*.getState(Button(u32), u32).?.*;

            closure.*.setText(std.fmt.allocPrint(closure.*.alloc, "{d}", .{count}) catch "Error");

            return true;
        }
    }.call, counter_text);

    var timer_text_box = Component.t.createNode(Box, .{});

    // TODO: add alignment property to styling and align to top-right
    timer_text_box.styling = .{ .default = .{
        .x = 800 - 128,
        .y = 16,
    } };

    const refresh_timer = try std.time.Timer.start();

    const TimerText = withState(Text, std.time.Timer);

    var timer_text = TimerText.init(.{ .alloc = alloc, .content = "0ms" });
    defer timer_text.deinit(Text);
    timer_text.setState(TimerText, refresh_timer);

    timer_text.styling = .{
        .default = .{
            .background = rl.Color.alpha(rl.Color.ray_white, 0.0),
        },
    };

    try timer_text.onEvent(.Draw, *Component, struct {
        pub fn call(comp: **Component) anyerror!bool {
            var timer = comp.*.getState(TimerText, std.time.Timer).?;
            comp.*.setText(std.fmt.allocPrint(comp.*.alloc, "{d}ms", .{timer.*.read() / 1_000_000}) catch "Error");
            timer.reset();
            return true;
        }
    }.call, timer_text);

    try initGrid(window);
    try fetchButton(window);

    try window.addChild(timer_text_box);
    try timer_text_box.addChild(timer_text);

    try window.draw();
}

const Box = struct {
    const Self = @This();

    component: Component,

    pub fn init(_: anytype) Box {
        const component = Component.init();
        return Box{ .component = component };
    }

    pub fn addChild(comp: *Component, comptime Child: type, props: anytype) !*Component {
        const child = Component.t.createNode(Child, props);
        try comp.addChild(child);

        return child;
    }
};

pub fn Button(comptime T: type) type {
    return struct {
        const Self = @This();

        const Props = struct {
            alloc: std.mem.Allocator,
            label: ?[]const u8 = null,
        };

        component: Component,

        state: T,
        props: Props,

        pub fn init(props: Props) *Component {
            const comp = Component.init();

            const self = props.alloc.create(Self) catch unreachable;

            self.* = Self{
                .component = comp,
                .state = 0,
                .props = props,
            };

            self.component.super = self;

            return &self.component;
        }
    };
}

const Window = struct {
    const Self = @This();
    var isInitalized: bool = false;

    component: Component,
    event_loop: *EventLoop,

    pub fn init(alloc: std.mem.Allocator) *Component {
        var comp = Component.init();
        comp.drawFn = &Self.draw;
        comp.setRectangle(Rectangle.init(0, 0, 800, 600));

        const self = alloc.create(Self) catch unreachable;

        self.* = Self{
            .component = comp,
            .event_loop = EventLoop.init(),
        };

        Component.t.componentTree = ComponentTree.init(alloc, &self.component) catch @panic("Window already initialized.");

        return &self.component;
    }

    pub fn draw(this: *Component) !void {
        const self = this.cast(Self);

        // raylib does not care about the first end if there was no begin
        rl.endDrawing();

        if (!self.event_loop.eval()) {
            // move this to be an effect as well
            rl.pollInputEvents();
        }

        std.Thread.sleep(10_000_000);

        // Initialize event waiting only once and after the first poll
        // This avoids pausing on startup
        if (!isInitalized) {
            rl.enableEventWaiting();

            isInitalized = true;
        }

        // Handle all events
        const pos = rl.getMousePosition();

        // TODO: make sure the mouse event does not re-trigger if the mouse has been moved
        if (rl.isMouseButtonDown(rl.MouseButton.left)) {
            try Component.t.componentTree.?.mouseLeftDown(@intFromFloat(pos.x), @intFromFloat(pos.y));
        }

        if (rl.isMouseButtonPressed(rl.MouseButton.left)) {
            try Component.t.componentTree.?.mouseLeftPress(@intFromFloat(pos.x), @intFromFloat(pos.y));
        }

        try Component.t.componentTree.?.mouseMove(@intFromFloat(pos.x), @intFromFloat(pos.y));

        // Close window if requested
        if (rl.windowShouldClose()) {
            return;
        }

        // Begin drawing
        rl.beginDrawing();
        rl.clearBackground(rl.Color.ray_white);

        // Any call to the component draw function will redraw all children as well
        // TODO: test if this is actual tail recursive
        // We might be blowing up the stack
        try this.draw();
    }
};

fn initGrid(window: *Component) !void {
    const grid = Component.t.createNode(Grid, .{ .cols = 2, .rows = 2 });

    grid.styling = .{ .default = .{ .gap = 16, .padding = .{ .All = 8 } } };

    try window.addChild(grid);
    const box = try Grid.addChild(grid, Box, .{}, 0, 0);
    _ = try Box.addChild(box, Text, .{ .content = "col = 0, row = 0" });

    const box2 = try Grid.addChild(grid, Box, .{}, 1, 1);
    _ = try Box.addChild(box2, Text, .{ .content = "box2" });
}

fn fetchButton(window: *Component) !void {
    const button = Component.t.createNode(components.Button, .{});
    const alloc = button.alloc;
    button.styling = .{ .default = .{ .padding = .{ .All = 32 } } };

    try window.addChild(button);

    const request = try ev.Fetch.init(alloc, "https://jsonplaceholder.typicode.com/posts/1");

    const text = try button.addGenericChild(Text, .{ .content = "Load" });
    std.log.debug("text_ uid: {d}", .{text.uid.id});

    const chain = request.task.then(*Component, void, struct {
        pub fn call(result: []const u8, t: *Component) Task(void, anyerror) {
            var text_ = t.cast(Text);
            text_.state = result;

            std.log.debug("text_ uid: {d}, content: {s}", .{ t.uid.id, text_.state });

            return .{ .state = .Resolved };
        }
    }.call, text);

    const closure = .{ .task = chain, .text = text };

    try button.onEvent(.MouseLeftDown, @TypeOf(closure), struct {
        pub fn call(c: *@TypeOf(closure)) anyerror!bool {
            const t = c.text.cast(Text);
            t.state = "Loading";

            TaskEffect(void, anyerror).init(@constCast(&c.task.task));

            return false;
        }
        // TODO: allow non ptr in here
    }.call, closure);
}
