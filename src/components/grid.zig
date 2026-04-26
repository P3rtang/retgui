const std = @import("std");
const rl = @import("raylib");

const Component = @import("./component.zig");
const tree = @import("./tree.zig");
const Uid = tree.Uid;
const merge = @import("mergeProps.zig").merge;

const Self = @This();

component: Component,
cols: u16,
rows: u16,

const Size = struct { rows: []i32, cols: []i32 };
const Position = struct { row: i32, col: i32 };

pub fn init(props: anytype) Self {
    var component = Component.init();

    component.drawFn = &Self.draw;
    component.childOffsetFn = &Self.childOffset;
    component.sizeFn = &Self.sizeFn;

    return Self{
        .component = component,
        .cols = @field(props, "cols"),
        .rows = @field(props, "rows"),
    };
}

fn draw(comp: *Component) !void {
    const rect = comp.rectangle();
    rl.drawRectangleLines(rect.x, rect.y, rect.width, rect.height, rl.Color.black);
}

fn childOffset(comp: *Component, uid: Uid) Component.Vector2Int {
    const self = comp.cast(Self);
    const style = comp.getStyling();

    const padding = style.default.padding.value();

    const size = self.getSize();
    const pos = self.getChildPosition(uid);

    const rect = comp.rectangle();

    if (pos) |p| {
        var x_offset: i32 = padding.left;
        var y_offset: i32 = padding.top;
        var i: usize = 0;

        while (i < p.col) : (i += 1) {
            x_offset += size.cols[i] + style.gap();
        }

        i = 0;
        while (i < p.row) : (i += 1) {
            y_offset += size.rows[i] + style.gap();
        }

        return .{ .x = rect.x + x_offset, .y = rect.y + y_offset };
    } else {
        return .{};
    }
}

fn getChildPosition(self: *Self, uid: Uid) ?Self.Position {
    const child = self.component.getChild(uid);

    if (child) |c| {
        const withGrid: *WithGrid = @fieldParentPtr("component", c);

        return .{ .col = withGrid.col, .row = withGrid.row };
    }

    return null;
}

fn sizeFn(comp: *Component) Component.Size {
    const self = comp.cast(Self);
    const style = comp.getStyling();

    var width: i32 = 0;
    var height: i32 = 0;

    const size = self.getSize();

    for (size.cols) |c| {
        width += c;
    }

    for (size.rows) |r| {
        height += r;
    }

    return .{
        .width = width + style.gap() * (self.cols - 1) + style.default.padding.value().left + style.default.padding.value().right,
        .height = height + style.gap() * (self.rows - 1) + style.default.padding.value().top + style.default.padding.value().bottom,
    };
}

fn getSize(self: *Self) Self.Size {
    const children = self.component.children;

    const size: Size = .{
        .cols = self.component.alloc.alloc(i32, self.cols) catch @panic("Out of memory"),
        .rows = self.component.alloc.alloc(i32, self.rows) catch @panic("Out of memory"),
    };

    for (children.items) |child| {
        const withGrid: *WithGrid = @fieldParentPtr("component", child);

        size.cols[withGrid.col] = withGrid.component.width(.{});
        size.rows[withGrid.row] = withGrid.component.height(.{});
    }

    return size;
}

pub fn addChild(comp: *Component, comptime Child: type, props: anytype, col: u16, row: u16) !*Component {
    const mergedProps = merge(props, .{ .col = col, .row = row, .child = Child });

    const with_grid = Component.t.createNode(WithGrid, mergedProps);

    try comp.addChild(with_grid);

    const child = Component.t.createNode(Child, props);
    with_grid.addChild(child) catch @panic("Out of memory");

    return with_grid;
}

pub const WithGrid = struct {
    component: Component,
    col: u16,
    row: u16,

    pub fn init(props: anytype) WithGrid {
        return WithGrid{
            .component = Component.init(),
            .col = @field(props, "col"),
            .row = @field(props, "row"),
        };
    }
};
