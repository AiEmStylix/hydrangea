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

pub fn modifyLetter(syllable: *TransformSyllable, modification: LetterModification) Transformation {
    if (syllable.isEmpty() or syllable.charsLen() > MAX_WORLD_LENGTH) {
        return .Ignored;
    }

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

    if (modification == .Horn) {
        if (std.mem.find(u8, &syllable.buffer, "uo")) |idx| {
            if (syllable.containsModification(.Horn)) {
                syllable.removeModification(.Horn);
                return .LetterModificationRemoved;
            }
            const entry: ModificationEntry = .{ .index = idx, .mod = .Horn };
            const result = syllable.addingLetterModifcation(entry) and syllable.addingLetterModifcation(.{ .index = idx + 1, .mod = .Horn });

            if (!result) return .Ignored;

            return .LetterModificationAdded;
        } else if (std.mem.findAny(u8, &syllable.buffer, "uo")) |idx| {
            if (syllable.containsModification(.Horn)) {
                syllable.removeModification(.Horn);
                return .LetterModificationRemoved;
            }
            const entry: ModificationEntry = .{ .index = idx, .mod = .Horn };
            const result = syllable.addingLetterModifcation(entry);

            if (!result) return .Ignored;

            return .LetterModificationAdded;
        } else {
            return .Ignored;
        }
    }

    if (modification == .Breve) {
        if (std.mem.findAny(u8, &syllable.buffer, "aA")) |idx| {
            if (syllable.containsModification(.Breve)) {
                syllable.removeModification(.Breve);
                return .LetterModificationRemoved;
            }
            const entry: ModificationEntry = .{ .index = idx, .mod = .Breve };
            const result = syllable.addingLetterModifcation(entry);

            if (!result) return .Ignored;
            return .LetterModificationAdded;
        } else {
            return .Ignored;
        }
    }

    if (modification == .Circumflex) {
        if (std.mem.findAny(u8, &syllable.buffer, "aeoAEO")) |idx| {
            if (syllable.containsModification(.Circumflex)) {
                syllable.removeModification(.Circumflex);
                return .LetterModificationRemoved;
            }
            const entry: ModificationEntry = .{ .index = idx, .mod = .Circumflex };
            const result = syllable.addingLetterModifcation(entry);

            if (!result) return .Ignored;

            return .LetterModificationAdded;
        } else {
            return .Ignored;
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

    try testing.expectEqual(Transformation.LetterModificationAdded, result);
    try testing.expectEqual(@as(?LetterModification, .Breve), syllable.letter_modifications[0].mod);
    try testing.expectEqual(1, syllable.letter_modification_len);
    try testing.expectEqual(0, syllable.letter_modifications[0].index);
    try testing.expectEqual(LetterModification.Breve, syllable.letter_modifications[0].mod);
}
