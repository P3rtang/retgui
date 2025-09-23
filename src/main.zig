const std = @import("std");

const retgui = @import("retgui");
const rl = @import("raylib");

const ev = @import("events");

const f = @import("components").font;
const getFontSize = f.getFontSize;

const components = @import("components");
const Text = components.Text;
const Component = components.Component;
const ComponentTree = components.ComponentTree;
const Rectangle = components.Rectangle;
const withState = components.withState;

const CONFIG_FLAGS = rl.ConfigFlags{
    .msaa_4x_hint = true,
    .window_resizable = false,
};

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    rl.setConfigFlags(CONFIG_FLAGS);
    rl.initWindow(800, 600, "retgui - example");

    const window = Window.init(alloc);
    defer window.deinit(Window);

    const body = Box.init(alloc);
    defer body.deinit(Box);

    body.styling = .{
        .default = .{
            .padding = .{ .All = 16 },
            .gap = 16,
        },
    };

    try window.addChild(body);

    var button = Button(u32).init(.{ .alloc = alloc });
    defer button.deinit(Button(u32));
    button.setState(Button(u32), u32, 0);

    try button.onEvent(.MouseLeftPress, .{
        .closure = button,
        .func = struct {
            pub fn call(_: ev.Event, closure: *Component) anyerror!bool {
                closure.getState(Button(u32), u32).?.* += 1;
                return true;
            }
        }.call,
    });

    button.styling = .{
        .default = .{
            .background = rl.Color.green,
            .border = .{
                .width = 2,
                .color = rl.Color.dark_green,
                .radius = 12,
            },
            .padding = .{ .Symmetric = .{ .vertical = 24, .horizontal = 32 } },
        },
        .onHover = .{
            .background = rl.Color.red,
        },
    };

    try body.addChild(button);

    const button_text = Text.init(.{ .alloc = alloc, .content = "Click me!" });
    defer button_text.deinit(Text);
    try button.addChild(button_text);

    const counter_box = Box.init(alloc);
    defer counter_box.deinit(Box);
    try body.addChild(counter_box);

    counter_box.styling = .{
        .default = .{
            .background = rl.Color.alpha(rl.Color.light_gray, 0.5),
            .border = .{
                .width = 2,
                .color = rl.Color.gray,
                .radius = 8,
            },
            .padding = .{ .Symmetric = .{ .vertical = 24, .horizontal = 32 } },
        },
    };

    const CounterText = withState(Text, *Component);

    const counter_text = CounterText.init(.{ .alloc = alloc, .content = "0" });
    defer counter_text.deinit(Text);

    try counter_box.addChild(counter_text);
    counter_text.setState(CounterText, *Component, button);

    try counter_text.onEvent(.Draw, .{
        .closure = counter_text,
        .func = struct {
            pub fn call(_: ev.Event, closure: *Component) anyerror!bool {
                const count = closure.getState(CounterText, *Component).?.*.getState(Button(u32), u32).?.*;

                closure.setText(std.fmt.allocPrint(closure.alloc, "{d}", .{count}) catch "Error");

                return true;
            }
        }.call,
    });

    var timer_text_box = Box.init(alloc);
    defer timer_text_box.deinit(Box);
    try body.addChild(timer_text_box);

    // TODO: add alignment property to styling and align to top-right
    timer_text_box.styling = .{ .default = .{
        .x = 800 - 128,
        .y = 16,
    } };

    const refresh_timer = try std.time.Timer.start();

    const TimerText = withState(Text, std.time.Timer);

    var timer_text = TimerText.init(.{ .alloc = alloc, .content = "0ms" });
    defer timer_text.deinit(Text);
    timer_text.setState(TimerText, std.time.Timer, refresh_timer);

    timer_text.styling = .{
        .default = .{
            .background = rl.Color.alpha(rl.Color.ray_white, 0.0),
        },
    };

    try timer_text_box.addChild(timer_text);

    try timer_text.onEvent(.Draw, .{
        .closure = timer_text,
        .func = struct {
            pub fn call(_: ev.Event, closure: *Component) anyerror!bool {
                var timer = closure.getState(TimerText, std.time.Timer).?;
                closure.setText(std.fmt.allocPrint(closure.alloc, "{d}ms", .{timer.*.read() / 1_000_000}) catch "Error");
                timer.reset();
                return true;
            }
        }.call,
    });

    try window.draw();
}

const Box = struct {
    const Self = @This();

    component: Component,

    pub fn init(alloc: std.mem.Allocator) *Component {
        const comp = Component.init(.{ .alloc = alloc });

        const self = alloc.create(Self) catch unreachable;

        self.* = Self{
            .component = comp,
        };

        return &self.component;
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
            const comp = Component.init(.{ .alloc = props.alloc });

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

    pub fn init(alloc: std.mem.Allocator) *Component {
        var comp = Component.init(.{ .alloc = alloc });
        comp.drawFn = &Self.draw;
        comp.setRectangle(Rectangle.init(0, 0, 800, 600));

        const self = alloc.create(Self) catch unreachable;

        self.* = Self{
            .component = comp,
        };

        Component.t.componentTree = ComponentTree.init(alloc, &self.component) catch @panic("Window already initialized.");

        return &self.component;
    }

    pub fn draw(this: *Component) !void {
        // raylib does not care about the first end if there was no begin
        rl.endDrawing();

        // Pause to avoid busy looping
        rl.pollInputEvents();

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
        try this.draw();
    }
};
