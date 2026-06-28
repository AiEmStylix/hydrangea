const std = @import("std");
const diacritics = @import("diacritics.zig");
const TransformSyllable = @import("syllable.zig").TransformSyllable;
const transform = @import("transform.zig");

pub const TelexAction = union(enum) {
    Tone: diacritics.ToneMark,
    Modification: diacritics.LetterModification,
    SpecialW,
    ClearZ,
    Literal: u8,
};

pub fn parseKey(c: u8) TelexAction {
    return switch (c) {
        's', 'S' => .{ .Tone = .Acute },
        'f', 'F' => .{ .Tone = .Grave },
        'r', 'R' => .{ .Tone = .HookAbove },
        'x', 'X' => .{ .Tone = .Tilde },
        'j', 'J' => .{ .Tone = .Underdot },

        'w', 'W' => .SpecialW,
        'z', 'Z' => .ClearZ,

        else => .{ .Literal = c },
    };
}

fn isDoubleTap(syllable: *TransformSyllable, current_char: u8) bool {
    const lower_current = std.ascii.toLower(current_char);
    for (syllable.buffer[0..syllable.total_len]) |c| {
        if (std.ascii.toLower(c) == lower_current) {
            return true;
        }
    }
    return false;
}

pub fn processKeyStroke(syllable: *TransformSyllable, char: u8) bool {
    const action = parseKey(char);

    switch (action) {
        .Literal => |c| {
            const lower_c = std.ascii.toLower(c);

            // Double tap
            if (lower_c == 'd' and isDoubleTap(syllable, c)) {
                const result = transform.modifyLetter(syllable, .Dyet);
                if (result != .Ignored) return true;
            } else if ((lower_c == 'a' or lower_c == 'e' or lower_c == 'o') and isDoubleTap(syllable, lower_c)) {
                const result = transform.modifyLetter(syllable, .Circumflex);
                if (result != .Ignored) return true;
            }

            syllable.appendChar(c);
            return true;
        },
        .Modification => |mod| {
            const result = transform.modifyLetter(syllable, mod);
            if (result == .Ignored) {
                syllable.appendChar(char);
            }
            return true;
        },
        .Tone => |t| {
            const result = transform.addTone(syllable, t);
            if (result == .Ignored) {
                syllable.appendChar(char);
            } else if (result == .ToneMarkRemoved) {
                syllable.appendChar(char);
            }
            return true;
        },
        .SpecialW => {
            var result = transform.modifyLetter(syllable, .Horn);

            if (result == .Ignored) {
                result = transform.modifyLetter(syllable, .Breve);
            }

            if (result == .Ignored) {
                syllable.appendChar(char);
            }
            return true;
        },
        .ClearZ => {
            return true;
        },
    }
}
