pub const Text = @import("text.zig");

pub const Component = @import("component.zig");
pub const ComponentTree = @import("tree.zig");
pub const Rectangle = Component.Rectangle;
pub const withState = @import("state.zig").withState;

const f = @import("font.zig");
pub const font = f.font;
pub const getFontSize = f.getFontSize;
