const std = @import("std");

const Writer = std.Io.File.Writer;

pub fn main(init: std.process.Init) !void {
    _ = init;
    std.debug.print("Hello World", .{});
}
