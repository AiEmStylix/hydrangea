const ToneMark = @import("diacritics.zig").ToneMark;
const diacritics = @import("diacritics.zig");
const LetterModification = diacritics.LetterModification;
const ModificationEntry = diacritics.ModificationEntry;

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
    letter_modifications: [2]ModificationEntry, // Maximum modification of a word is 2
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

    pub fn initialConsonant(self: *const Self) []const u8 {
        return self.buffer[0..self.initial_len];
    }

    pub fn vowel(self: *const Self) []const u8 {
        return self.buffer[self.initial_len .. self.initial_len + self.vowel_len];
    }

    pub fn finalConsonant(self: *const Self) []const u8 {
        const start = self.initial_len + self.vowel_len;
        return self.buffer[start .. start + self.final_len];
    }

    pub fn isEmpty(self: *const Self) bool {
        return self.total_len == 0;
    }

    pub fn containsModification(self: *const Self, mod: LetterModification) bool {
        for (self.letter_modifications[0..self.letter_modification_len]) |entry| {
            if (entry.modification == mod) return true;
        }
        return false;
    }
};
