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

pub fn init(props: anytype) Self {
    var component = Component.init();

    component.drawFn = &Self.draw;
    component.childOffsetFn = &Self.childOffset;

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

pub fn addChild(comp: *Component, comptime Child: type, props: anytype, col: u16, row: u16) !*Component {
    const mergedProps = merge(props, .{ .col = col, .row = row, .child = Child });

    const with_grid = Component.t.createNode(WithGrid, mergedProps);

    try comp.addChild(with_grid);

    return with_grid;
}

pub const WithGrid = struct {
    component: *Component,
    col: u16,
    row: u16,

    pub fn init(props: anytype) WithGrid {
        const component = Component.t.createNode(props.child, props);

        return WithGrid{
            .component = component,
            .col = @field(props, "col"),
            .row = @field(props, "row"),
        };
    }
};
