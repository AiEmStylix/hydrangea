const std = @import("std");
const testing = std.testing;
const diacritics = @import("diacritics.zig");
const TransformSyllable = @import("syllable.zig").TransformSyllable;
const LetterModification = diacritics.LetterModification;
const ModificationEntry = diacritics.ModificationEntry;
const ToneMark = diacritics.ToneMark;

/// Core of engine
const MAX_WORLD_LENGTH = 7;

pub const Transformation = enum {
    ToneMarkAdded,
    ToneMarkReplaced,
    ToneMarkRemoved,

    LetterModificationAdded,
    LetterModificationReplaced,
    LetterModificationRemoved,

    Ignored,
};

pub fn addTone(syllable: *TransformSyllable, tone_mark: ToneMark) Transformation {
    if (syllable.isEmpty() or syllable.total_len > MAX_WORLD_LENGTH) {
        return .Ignored;
    }

    if (syllable.vowel().len == 0) {
        return .Ignored;
    }

    if (syllable.tone_mark) |existing_tone_mark| {
        if (existing_tone_mark == tone_mark) {
            syllable.tone_mark = null;
            return .ToneMarkRemoved;
        } else {
            syllable.tone_mark = tone_mark;
            return .ToneMarkReplaced;
        }
    } else {
        syllable.tone_mark = tone_mark;
        return .ToneMarkAdded;
    }
}

pub fn removeTone(input: *TransformSyllable) Transformation {
    if (input.buffer.len > MAX_WORLD_LENGTH) {
        return .Ignored;
    }

    if (input.tone_mark != null) {
        input.tone_mark = null;
        return .ToneMarkRemoved;
    }

    return .Ignored;
}

// Hardest thing i ever implement
// Might need to rework the function a little bit more
// I need to remade this function to handle the letter modification action-based
pub fn modifyLetter(syllable: *TransformSyllable, modification: LetterModification) Transformation {
    if (syllable.isEmpty() or syllable.total_len > MAX_WORLD_LENGTH) {
        return .Ignored;
    }

    const vowel = syllable.vowel();

    var buf: [64]u8 = undefined;
    const lower = std.ascii.lowerString(buf[0..vowel.len], vowel);
    // Phần dễ nhất, thanh ngang thì chỉ có thêm hoặc xóa,
    // không có bị ai chen vào, ước gì đống sau cũng dễ như thế TT
    if (modification == .Dyet) {
        if (syllable.buffer[0] == 'd' or syllable.buffer[0] == 'D') {
            if (syllable.containsModification(.Dyet)) {
                syllable.removeModification(.Dyet);
                return .LetterModificationRemoved;
            }
            const entry: ModificationEntry = .{ .index = 0, .mod = .Dyet };
            const result = syllable.addingLetterModifcation(entry);

            if (!result) return .Ignored;

            return .LetterModificationAdded;
        }
    }

    // Dấu trăng (Breve) chỉ có với chữ a thôi nên xử lý rất nhanh
    if (modification == .Breve) {
        if (std.mem.find(u8, lower, "a")) |offset| {
            if (syllable.containsModification(.Breve)) {
                syllable.removeModification(.Breve);
                return .LetterModificationRemoved;
            }

            // Nếu từ đó đã có dấu mũ, thay thế nó bằng dấu trăng
            if (syllable.containsModification(.Circumflex)) {
                syllable.replaceModificationAt(offset, .Breve);
                return .LetterModificationReplaced;
            }

            const entry: ModificationEntry = .{ .index = offset, .mod = .Breve };
            const result = syllable.addingLetterModifcation(entry);

            if (!result) return .Ignored;
            return .LetterModificationAdded;
        }
    }

    if (modification == .Circumflex) {
        if (std.mem.find(u8, lower, "e")) |offset| {
            const target_idx = syllable.vowelStartIdx() + offset;

            if (syllable.containsModification(.Circumflex)) {
                syllable.removeModification(.Circumflex);
                return .LetterModificationRemoved;
            }

            const result = syllable.addingLetterModifcation(.{ .index = target_idx, .mod = .Circumflex });
            return if (result) .LetterModificationAdded else .Ignored;
        } else if (std.mem.find(u8, lower, "a")) |offset| {
            const target_idx = syllable.vowelStartIdx() + offset;

            if (syllable.containsModification(.Circumflex)) {
                syllable.removeModification(.Circumflex);
                return .LetterModificationRemoved;
            }

            if (syllable.containsModification(.Breve)) {
                syllable.replaceModificationAt(target_idx, .Circumflex);
                return .LetterModificationReplaced;
            }
            const result = syllable.addingLetterModifcation(.{ .index = target_idx, .mod = .Circumflex });
            return if (result) .LetterModificationAdded else .Ignored;
        } else if (std.mem.find(u8, lower, "o")) |offset| {
            const target_idx = syllable.vowelStartIdx() + offset;

            if (syllable.containsModification(.Circumflex)) {
                syllable.removeModification(.Circumflex);
                return .LetterModificationRemoved;
            }

            if (syllable.containsModification(.Horn)) {
                syllable.removeModification(.Horn);
                _ = syllable.addingLetterModifcation(.{ .index = target_idx, .mod = .Circumflex });
                return .LetterModificationReplaced;
            }
            const result = syllable.addingLetterModifcation(.{ .index = target_idx, .mod = .Circumflex });
            return if (result) .LetterModificationAdded else .Ignored;
        }
    }

    if (modification == .Horn) {
        if (std.mem.find(u8, lower, "uo")) |offset| {
            const u_idx = syllable.vowelStartIdx() + offset;
            const o_idx = u_idx + 1;
            if (syllable.containsModification(.Horn)) {
                syllable.removeModification(.Horn);
                return .LetterModificationRemoved;
            }
            if (syllable.containsModification(.Circumflex)) {
                syllable.removeModification(.Circumflex);

                _ = syllable.addingLetterModifcation(.{ .index = u_idx, .mod = .Horn });
                _ = syllable.addingLetterModifcation(.{ .index = o_idx, .mod = .Horn });
                return .LetterModificationReplaced;
            }

            _ = syllable.addingLetterModifcation(.{ .index = u_idx, .mod = .Horn });
            _ = syllable.addingLetterModifcation(.{ .index = o_idx, .mod = .Horn });
            return .LetterModificationAdded;
        } else if (std.mem.find(u8, lower, "u")) |offset| {
            const target_idx = syllable.vowelStartIdx() + @as(u8, @intCast(offset));

            if (syllable.containsModification(.Horn)) {
                syllable.removeModification(.Horn);
                return .LetterModificationRemoved;
            }

            const result = syllable.addingLetterModifcation(.{ .index = target_idx, .mod = .Horn });
            return if (result) .LetterModificationAdded else .Ignored;
        } else if (std.mem.find(u8, lower, "o")) |offset| {
            const target_idx = syllable.vowelStartIdx() + offset;
            if (syllable.containsModification(.Horn)) {
                syllable.removeModification(.Horn);
                return .LetterModificationRemoved;
            }

            if (syllable.containsModification(.Circumflex)) {
                syllable.replaceModificationAt(target_idx, .Horn);
                return .LetterModificationReplaced;
            }
            const entry: ModificationEntry = .{ .index = target_idx, .mod = .Horn };
            const result = syllable.addingLetterModifcation(entry);

            if (!result) return .Ignored;
            return .LetterModificationAdded;
        }
    }

    return .Ignored;
}

test "Add, replace, and remove tone" {
    var syllable = TransformSyllable.init();
    syllable.appendChar('a');
    try testing.expectEqual(@as(?ToneMark, null), syllable.tone_mark);

    // ---------------------------------------------------------
    // KỊCH BẢN 1: Chưa có dấu -> Gõ phím thêm dấu Sắc (.Acute)
    // ---------------------------------------------------------
    var result = addTone(&syllable, .Acute);

    try testing.expectEqual(Transformation.ToneMarkAdded, result);
    try testing.expectEqual(@as(?ToneMark, .Acute), syllable.tone_mark);

    // ---------------------------------------------------------
    // KỊCH BẢN 2: Đang có dấu Sắc -> Gõ phím đổi dấu Huyền (.Grave)
    // ---------------------------------------------------------
    result = addTone(&syllable, .Grave);

    try testing.expectEqual(Transformation.ToneMarkReplaced, result);
    try testing.expectEqual(@as(?ToneMark, .Grave), syllable.tone_mark);

    // ---------------------------------------------------------
    // KỊCH BẢN 3: Đang có dấu Huyền -> Gõ lại phím Huyền (.Grave) để xóa
    // ---------------------------------------------------------
    result = addTone(&syllable, .Grave);

    try testing.expectEqual(Transformation.ToneMarkRemoved, result);
    try testing.expectEqual(@as(?ToneMark, null), syllable.tone_mark);
}

test "Modify letter (dyet)" {
    var syllable = TransformSyllable.init();
    syllable.appendChar('d');
    var result = modifyLetter(&syllable, .Dyet);

    try testing.expectEqual(Transformation.LetterModificationAdded, result);
    try testing.expectEqual(@as(?LetterModification, .Dyet), syllable.letter_modifications[0].mod);

    result = modifyLetter(&syllable, .Dyet);

    try testing.expectEqual(Transformation.LetterModificationRemoved, result);
    try testing.expectEqual(0, syllable.letter_modification_len);
}

test "Modify letter (horn)" {
    var syllable = TransformSyllable.init();
    syllable.appendChar('d');
    syllable.appendChar('u');
    syllable.appendChar('o');
    syllable.appendChar('c');

    var result = modifyLetter(&syllable, .Horn);

    try testing.expectEqual(Transformation.LetterModificationAdded, result);
    try testing.expectEqual(@as(?LetterModification, .Horn), syllable.letter_modifications[0].mod);
    try testing.expectEqual(2, syllable.letter_modification_len);
    try testing.expectEqual(1, syllable.letter_modifications[0].index);
    try testing.expectEqual(2, syllable.letter_modifications[1].index);

    result = modifyLetter(&syllable, .Horn);
    try testing.expectEqual(Transformation.LetterModificationRemoved, result);
    try testing.expectEqual(0, syllable.letter_modification_len);
}

test "Modify letter (Breve)" {
    var syllable = TransformSyllable.init();
    syllable.appendChar('a');

    const result = modifyLetter(&syllable, .Breve);

    var syllable2 = TransformSyllable.init();
    syllable2.appendChar('b');
    syllable2.appendChar('u');
    syllable2.appendChar('o');
    syllable2.appendChar('n');
    syllable2.appendChar('g');

    try testing.expectEqual(Transformation.LetterModificationAdded, result);
    try testing.expectEqual(@as(?LetterModification, .Breve), syllable.letter_modifications[0].mod);
    try testing.expectEqual(1, syllable.letter_modification_len);
    try testing.expectEqual(0, syllable.letter_modifications[0].index);
    try testing.expectEqual(LetterModification.Breve, syllable.letter_modifications[0].mod);
}

test "Modify letter from Horn to Circumflex" {
    var syllable = TransformSyllable.init();
    syllable.appendChar('b');
    syllable.appendChar('u');
    syllable.appendChar('o');
    syllable.appendChar('n');
    syllable.appendChar('g');

    const result = modifyLetter(&syllable, .Horn);

    try testing.expectEqual(Transformation.LetterModificationAdded, result);
    try testing.expectEqual(@as(?LetterModification, .Horn), syllable.letter_modifications[0].mod);
    try testing.expectEqual(@as(?LetterModification, .Horn), syllable.letter_modifications[1].mod);

    const mod2 = modifyLetter(&syllable, .Circumflex);
    try testing.expectEqual(Transformation.LetterModificationReplaced, mod2);
    try testing.expectEqual(@as(?LetterModification, .Circumflex), syllable.letter_modifications[0].mod);
}
