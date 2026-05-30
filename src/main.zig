const std = @import("std");

const Writer = std.Io.File.Writer;

pub fn main(init: std.process.Init) !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = Writer.init(std.Io.File.stdout(), init.io, &stdout_buffer);

    const stdout = &stdout_writer.interface;

    var it = std.mem.splitSequence(u8, "a, b ,, c, d, e", ", ");

    while (it.next()) |word| {
        try stdout.print("word: {s}\n\n|rest:{s}\n", .{ word, it.rest() });
    }

    try stdout.print("Hello, {s} \n", .{"World"});
    try stdout.flush();
}
