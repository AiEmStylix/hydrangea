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

pub fn parseSyllable(input: []const u8) !SyllableComponents {
    if (input.len == 0) {
        return .{ .initial_consonant = "", .vowel = "", .final_consonant = "" };
    }
    var init_len: usize = 0;

    const is_gi = input.len >= 2 and std.ascii.toLower(input[0]) == 'g' and std.ascii.toLower(input[1]) == 'i';
    const is_qu = input.len >= 2 and std.ascii.toLower(input[0]) == 'q' and std.ascii.toLower(input[1]) == 'u';

    // Extract init consonant
    if (is_gi) {
        var has_vowel_after_gi = false;
        if (input.len > 2) {
            var view = try unicode.Utf8View.init(input[2..]);
            var iter = view.iterator();
            if (iter.nextCodepoint()) |cp| {
                if (char_map.isVowel(cp)) has_vowel_after_gi = true;
            }
        }
        init_len = if (!has_vowel_after_gi) 1 else 2;
    } else if (is_qu) {
        init_len = 2;
    } else {
        var view = try unicode.Utf8View.init(input);
        var iter = view.iterator();
        while (iter.nextCodepointSlice()) |slice| {
            const cp = try unicode.utf8Decode(slice);
            if (char_map.isVowel(cp)) break;
            init_len += slice.len;
        }
    }
    const init_consonant = input[0..init_len];
    const after_consonant = input[init_len..];

    // Extract vovel
    var vowel_len: usize = 0;
    var view2 = try unicode.Utf8View.init(after_consonant);
    var iter2 = view2.iterator();
    while (iter2.nextCodepointSlice()) |slice| {
        const cp = try unicode.utf8Decode(slice);
        if (!char_map.isVowel(cp)) break;
        vowel_len += slice.len;
    }

    const vowel = after_consonant[0..vowel_len];
    const final_consonant = after_consonant[vowel_len..];

    return .{ .initial_consonant = init_consonant, .vowel = vowel, .final_consonant = final_consonant };
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

test "parseSyllable: Phụ âm đơn bình thường" {
    const res = try parseSyllable("toán");
    try testing.expectEqualStrings("t", res.initial_consonant);
    try testing.expectEqualStrings("oá", res.vowel);
    try testing.expectEqualStrings("n", res.final_consonant);
}

test "parseSyllable: Phụ âm kép/ba" {
    const res = try parseSyllable("nghiêng");
    try testing.expectEqualStrings("ngh", res.initial_consonant);
    try testing.expectEqualStrings("iê", res.vowel);
    try testing.expectEqualStrings("ng", res.final_consonant);

    const res2 = try parseSyllable("chuyển");
    try testing.expectEqualStrings("ch", res2.initial_consonant);
    try testing.expectEqualStrings("uyể", res2.vowel);
    try testing.expectEqualStrings("n", res2.final_consonant);
}

test "parseSyllable: Không có phụ âm đầu" {
    const res = try parseSyllable("áo");
    try testing.expectEqualStrings("", res.initial_consonant);
    try testing.expectEqualStrings("áo", res.vowel);
    try testing.expectEqualStrings("", res.final_consonant);

    const res2 = try parseSyllable("ươm");
    try testing.expectEqualStrings("", res2.initial_consonant);
    try testing.expectEqualStrings("ươ", res2.vowel);
    try testing.expectEqualStrings("m", res2.final_consonant);
}

test "parseSyllable: Không có phụ âm cuối" {
    const res = try parseSyllable("đi");
    try testing.expectEqualStrings("đ", res.initial_consonant);
    try testing.expectEqualStrings("i", res.vowel);
    try testing.expectEqualStrings("", res.final_consonant);
}

test "parseSyllable: Cụm đặc biệt 'GI'" {
    // Trường hợp 1: Có nguyên âm đi sau -> Phụ âm đầu là "gi"
    const res1 = try parseSyllable("giá");
    try testing.expectEqualStrings("gi", res1.initial_consonant);
    try testing.expectEqualStrings("á", res1.vowel);
    try testing.expectEqualStrings("", res1.final_consonant);

    // Trường hợp 2: Không có nguyên âm đi sau -> Phụ âm đầu là "g"
    const res2 = try parseSyllable("gì");
    try testing.expectEqualStrings("g", res2.initial_consonant);
    try testing.expectEqualStrings("ì", res2.vowel);
    try testing.expectEqualStrings("", res2.final_consonant);

    // Trường hợp 3: Chữ "gi" đứng một mình
    const res3 = try parseSyllable("gi");
    try testing.expectEqualStrings("g", res3.initial_consonant);
    try testing.expectEqualStrings("i", res3.vowel);
    try testing.expectEqualStrings("", res3.final_consonant);

    // Trường hợp 4: Viết hoa
    const res4 = try parseSyllable("Giêng");
    try testing.expectEqualStrings("Gi", res4.initial_consonant);
    try testing.expectEqualStrings("ê", res4.vowel);
    try testing.expectEqualStrings("ng", res4.final_consonant);
}

test "parseSyllable: Cụm đặc biệt 'QU'" {
    const res1 = try parseSyllable("quốc");
    try testing.expectEqualStrings("qu", res1.initial_consonant);
    try testing.expectEqualStrings("ố", res1.vowel);
    try testing.expectEqualStrings("c", res1.final_consonant);

    const res2 = try parseSyllable("Quanh");
    try testing.expectEqualStrings("Qu", res2.initial_consonant);
    try testing.expectEqualStrings("a", res2.vowel);
    try testing.expectEqualStrings("nh", res2.final_consonant);
}

test "parseSyllable: Chuỗi rỗng" {
    const res = try parseSyllable("");
    try testing.expectEqualStrings("", res.initial_consonant);
    try testing.expectEqualStrings("", res.vowel);
    try testing.expectEqualStrings("", res.final_consonant);
}
