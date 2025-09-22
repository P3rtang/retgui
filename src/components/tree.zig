const std = @import("std");
const ev = @import("events");

const Component = @import("component.zig");

const Self = @This();

pub var componentTree: ?Self = null;

pub const Uid = struct {
    id: u64,

    pub fn init() Uid {
        var rand = std.Random.DefaultPrng.init(@intCast(std.time.microTimestamp()));

        return Uid{ .id = rand.next() };
    }
};

const ComponentNode = struct {
    children: std.ArrayList(Uid),
    component: *Component,
    parent: ?Uid,

    pub fn propagate(self: *ComponentNode, func: *const fn (*ComponentNode) anyerror!void) !void {
        if (self.parent) |p| {
            if (componentTree.?.nodes.getPtr(p)) |parent_node| {
                try func(parent_node);
                try parent_node.propagate(func);
            }
        }
    }

    pub fn propagateEvent(self: *ComponentNode, event: ev.Event) !void {
        const do_propagate = try self.component.dispatchEvent(event);

        if (self.parent) |p| {
            if (componentTree.?.nodes.getPtr(p)) |parent_node| {
                if (do_propagate) {
                    try parent_node.propagateEvent(event);
                }
            }
        }
    }

    pub fn isLeaf(self: *ComponentNode) bool {
        return self.children.items.len == 0;
    }

    pub fn findLeafNode(self: *ComponentNode, x: i32, y: i32) ?*ComponentNode {
        const rect = self.component.rectangle();
        const width: i32 = @intCast(rect.width);
        const height: i32 = @intCast(rect.height);

        const is_self_hit = x >= rect.x and x <= rect.x + width and y >= rect.y and y <= rect.y + height;

        if (is_self_hit) {
            for (self.children.items) |child| {
                if (componentTree.?.nodes.getPtr(child).?.findLeafNode(x, y)) |comp| {
                    return comp;
                }
            }

            return self;
        }

        return null;
    }
};

alloc: std.mem.Allocator,
root: Uid,
nodes: std.AutoHashMapUnmanaged(Uid, ComponentNode),

pub fn init(alloc: std.mem.Allocator, root: *Component) !Self {
    if (componentTree) |_| {
        return error.SelfAlreadyInitialized;
    }

    const node = ComponentNode{
        .children = std.ArrayList(Uid).empty,
        .component = root,
        .parent = null,
    };

    var nodes = std.AutoHashMapUnmanaged(Uid, ComponentNode).empty;

    nodes.put(alloc, root.uid, node) catch @panic("Out of memory");

    return Self{
        .alloc = alloc,
        .root = root.uid,
        .nodes = nodes,
    };
}

pub fn getRoot(self: *Self) *ComponentNode {
    return self.nodes.getPtr(self.root).?;
}

pub fn addNode(self: *Self, parent_: *Component, child_: *Component) !void {
    if (self.nodes.getPtr(parent_.uid)) |n| {
        std.log.info("Adding child {} to parent {}", .{ child_.uid.id, parent_.uid.id });

        const node = ComponentNode{
            .children = std.ArrayList(Uid).empty,
            .component = child_,
            .parent = n.component.uid,
        };

        try n.children.append(self.alloc, child_.uid);
        try self.nodes.put(self.alloc, child_.uid, node);

        return;
    }

    return error.ParentNotFound;
}

pub fn mouseLeftDown(self: *Self, x: i32, y: i32) !void {
    const node = self.getRoot().findLeafNode(x, y);

    if (node) |comp| {
        const event = ev.Event{
            .MouseLeftDown = .{
                .x = x,
                .y = y,
            },
        };

        try comp.propagateEvent(event);
    }
}

pub fn mouseLeftPress(self: *Self, x: i32, y: i32) !void {
    const node = self.getRoot().findLeafNode(x, y);

    if (node) |comp| {
        const event = ev.Event{
            .MouseLeftPress = .{
                .x = x,
                .y = y,
            },
        };

        try comp.propagateEvent(event);
    }
}

pub fn mouseMove(self: *Self, x: i32, y: i32) !void {
    const node = self.getRoot().findLeafNode(x, y);
    var iter = self.nodes.valueIterator();

    // Reset all other components
    while (iter.next()) |n| {
        n.component.selectors = n.component.selectors.remove(.Hover);
    }

    if (node) |comp| {
        comp.component.selectors = comp.component.selectors.add(.Hover);

        try comp.propagate(struct {
            pub fn call(n: *ComponentNode) anyerror!void {
                n.component.selectors = n.component.selectors.add(.Hover);
            }
        }.call);
    }
}
