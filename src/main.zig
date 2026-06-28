const std = @import("std");
const TransformSyllable = @import("syllable.zig").TransformSyllable;
const telex = @import("telex.zig");
const print = std.debug.print;

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    // Sửa lỗi 2: Tăng buffer lên mức an toàn (1024 bytes)
    var read_buf: [1024]u8 = undefined;

    var stdin_reader = std.Io.File.stdin().reader(io, &read_buf);
    const stdin = &stdin_reader.interface;

    var syllable = TransformSyllable.init();
    var out_buf: [32]u8 = undefined;

    while (true) {
        syllable = syllable.reset();
        const line = stdin.takeDelimiterExclusive('\n') catch |err| {
            if (err == error.EndOfStream) break;
            return err;
        };

        for (line) |c| {
            _ = telex.processKeyStroke(&syllable, c);
        }

        _ = stdin.takeByte() catch |err| {
            if (err == error.EndOfStream) break;
        };

        // Bây giờ so sánh mới chuẩn xác
        if (std.mem.eql(u8, line, "exit")) {
            print("Đã nhận lệnh exit. Đang thoát...\n", .{});
            break;
        }

        print("Chuỗi bạn vừa nhập: {s}\n", .{line});
        const renderText = try syllable.rendertoUtf8(&out_buf);
        print("{s}\n", .{renderText});
    }
    std.debug.print("{s}\n", .{read_buf});
}
