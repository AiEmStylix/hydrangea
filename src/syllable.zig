const ToneMark = @import("diacritics.zig").ToneMark;
const ModificationEntry = @import("diacritics.zig").ModificationEntry;

pub const SyllableComponents = struct {
    initial_consonant: []const u8,
    vowel: []const u8,
    final_consonant: []const u8,
};

const MAX_SYLLABLE_LEN = 16;

//Represent syllable that currently being transform
pub const TransformSyllable = struct {
    buffer: [MAX_SYLLABLE_LEN]u8, // Store clean text
    total_len: u4,

    initial_len: u4, // 0..16
    vowel_len: u4,
    final_len: u4,

    tone_mark: ?ToneMark,
    letter_modifications: [2]ModificationEntry,
    letter_modification_len: u2,

    const Self = @This();

    pub fn init() Self {
        return .{
            .buffer = undefined,
            .total_len = 0,
            .initial_len = 0,
            .vowel_len = 0,
            .final_len = 0,
            .tone_mark = null,
            .letter_modifications = undefined,
            .letter_modification_len = 0,
        };
    }
};
