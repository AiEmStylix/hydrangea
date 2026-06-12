const std = @import("std");
const testing = std.testing;
const diacritics = @import("diacritics.zig");
const TransformSyllable = @import("syllable.zig").TransformSyllable;
const LetterModification = diacritics.LetterModification;
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
    if (syllable.isEmpty() or syllable.charsLen() > MAX_WORLD_LENGTH) {
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
    if (input.charsLen() > MAX_WORLD_LENGTH) {
        return .Ignored;
    }

    if (input.tone_mark != null) {
        input.tone_mark = null;
        return .ToneMarkRemoved;
    }

    return .Ignored;
}

// pub fn modifyLetter(syllable: *TransformSyllable, modification: LetterModification) Transformation {
//     if (syllable.isEmpty() or syllable.charsLen() > MAX_WORLD_LENGTH) {
//         return .Ignored;
//     }
// }

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
