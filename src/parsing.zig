// Module import
const std = @import("std");
const diacritics = @import("diacritics.zig");
const char_map = @import("char_map.zig");

const unicode = std.unicode;
const testing = std.testing;
const ToneMark = diacritics.ToneMark;
const ArrayList = std.ArrayList;
const LetterModification = diacritics.LetterModification;

pub const SyllableComponents = struct {
    initial_consonant: []const u8,
    vowel: []const u8,
    final_consonant: []const u8,
};

pub const ModResult = struct {
    index: usize,
    mod: LetterModification,
};

fn extractToneChar(cp: u21) ?ToneMark {
    return switch (cp) {
        'á', 'ấ', 'ắ', 'é', 'ế', 'í', 'ó', 'ố', 'ớ', 'ú', 'ứ', 'ý', 'Á', 'Ấ', 'Ắ', 'É', 'Ế', 'Í', 'Ó', 'Ố', 'Ớ', 'Ú', 'Ứ', 'Ý' => .Acute,
        'à', 'ầ', 'ằ', 'è', 'ề', 'ì', 'ò', 'ồ', 'ờ', 'ù', 'ừ', 'ỳ', 'À', 'Ầ', 'Ằ', 'È', 'Ề', 'Ì', 'Ò', 'Ồ', 'Ờ', 'Ù', 'Ừ', 'Ỳ' => .Grave,
        'ả', 'ẩ', 'ẳ', 'ẻ', 'ể', 'ỉ', 'ỏ', 'ổ', 'ở', 'ủ', 'ử', 'ỷ', 'Ả', 'Ẩ', 'Ẳ', 'Ẻ', 'Ể', 'Ỉ', 'Ỏ', 'Ổ', 'Ở', 'Ủ', 'Ử', 'Ỷ' => .HookAbove,
        'ã', 'ẫ', 'ẵ', 'ẽ', 'ễ', 'ĩ', 'õ', 'ỗ', 'ỡ', 'ũ', 'ữ', 'ỹ', 'Ã', 'Ẫ', 'Ẵ', 'Ẽ', 'Ễ', 'Ĩ', 'Õ', 'Ỗ', 'Ỡ', 'Ũ', 'Ữ', 'Ỹ' => .Tilde,
        'ạ', 'ậ', 'ặ', 'ẹ', 'ệ', 'ị', 'ọ', 'ộ', 'ợ', 'ụ', 'ự', 'ỵ', 'Ạ', 'Ậ', 'Ặ', 'Ẹ', 'Ệ', 'Ị', 'Ọ', 'Ộ', 'Ợ', 'Ụ', 'Ự', 'Ỵ' => .Underdot,
        else => null,
    };
}

pub fn extractTone(input: []const u8) !?ToneMark {
    var utf8_view = try unicode.Utf8View.init(input);
    var iter = utf8_view.iterator();

    while (iter.nextCodepoint()) |cp| {
        if (extractToneChar(cp)) |tone_mark| {
            return tone_mark;
        }
    }
    return null;
}

pub fn extractLetterModification(allocator: std.mem.Allocator, input: []const u8) ![]ModResult {
    var utf8_view = try unicode.Utf8View.init(input);
    var iter = utf8_view.iterator();

    var result: ArrayList(ModResult) = .empty;
    errdefer result.deinit(allocator);
    var current_index: usize = 0;

    while (iter.nextCodepoint()) |cp| {
        if (char_map.getModification(cp)) |mod| {
            try result.append(allocator, .{ .index = current_index, .mod = mod });
        }
        current_index += 1;
    }
    return result.toOwnedSlice(allocator);
}

test "extract correct Tone" {
    try testing.expectEqual(.Acute, (try extractTone("Tiếng")).?);
    try testing.expectEqual(.Grave, (try extractTone("Ngày")).?);
    try testing.expectEqual(.HookAbove, (try extractTone("Hỏi")).?);
    try testing.expectEqual(.Tilde, (try extractTone("Ngã")).?);
    try testing.expectEqual(.Underdot, (try extractTone("Nặng")).?);
    try testing.expectEqual(@as(?ToneMark, null), (try extractTone("Ngon")));
}

test "Invalid UTF-8 " {
    const invalid_utf8 = "\xff\xfe";

    try testing.expectError(error.InvalidUtf8, extractTone(invalid_utf8));
}

test "No modification" {
    const text = "hello";
    const result = try extractLetterModification(testing.allocator, text);

    defer testing.allocator.free(result);

    try testing.expectEqual(@as(usize, 0), result.len);
}

test "1 modification" {
    const text = "đi";
    const result = try extractLetterModification(testing.allocator, text);

    defer testing.allocator.free(result);

    try testing.expectEqual(@as(usize, 1), result.len);
    try testing.expectEqual(@as(usize, 0), result[0].index);
    try testing.expectEqual(LetterModification.Dyet, result[0].mod);
}

test "Many modification" {
    const text = "được";
    // This letter has 3 modification:
    // index 0: đ => dyet
    // index 1: ư => horn
    // index 2: ợ => horn
    const result = try extractLetterModification(testing.allocator, text);
    defer testing.allocator.free(result);

    try testing.expectEqual(@as(usize, 3), result.len);

    try testing.expectEqual(@as(usize, 0), result[0].index);
    try testing.expectEqual(LetterModification.Dyet, result[0].mod);

    try testing.expectEqual(@as(usize, 1), result[1].index);
    try testing.expectEqual(LetterModification.Horn, result[1].mod);

    try testing.expectEqual(@as(usize, 2), result[2].index);
    try testing.expectEqual(LetterModification.Horn, result[2].mod);
}

test "Modification with capital letter" {
    const text = "Ước";
    // This letter has 2 modifications:
    // index 0: Ư => horn
    // index 1: ớ => horn
    const result = try extractLetterModification(testing.allocator, text);
    defer testing.allocator.free(result);

    try testing.expectEqual(@as(usize, 2), result.len);

    try testing.expectEqual(@as(usize, 0), result[0].index);
    try testing.expectEqual(LetterModification.Horn, result[0].mod);

    try testing.expectEqual(@as(usize, 1), result[1].index);
    try testing.expectEqual(LetterModification.Horn, result[1].mod);
}
