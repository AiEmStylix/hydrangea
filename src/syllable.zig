const std = @import("std");
const unicode = std.unicode;
const transform = @import("transform.zig");
const ToneMark = @import("diacritics.zig").ToneMark;
const parsing = @import("parsing.zig");
const diacritics = @import("diacritics.zig");
const char_map = @import("char_map.zig");
const LetterModification = diacritics.LetterModification;
const ModificationEntry = diacritics.ModificationEntry;

const MAX_SYLLABLE_LEN = 16;

//Represent syllable that currently being transform
pub const TransformSyllable = struct {
    buffer: [MAX_SYLLABLE_LEN]u8, // Store clean text
    total_len: u8,

    initial_len: u8, // 0..16
    vowel_len: u8,
    final_len: u8,

    tone_mark: ?ToneMark,
    letter_modifications: [3]ModificationEntry, // Maximum letter modification is 3, for example: được (đ, ư, ơ)
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

    pub fn reset(self: *Self) Self {
        self.* = Self.init();
        return self.*;
    }

    pub fn appendChar(self: *Self, char: u8) void {
        if (self.total_len >= MAX_SYLLABLE_LEN) return;

        self.buffer[self.total_len] = char;
        self.total_len += 1;

        self.reparseBoundaries();
    }

    // Auto calculate the syllable's component length
    pub fn reparseBoundaries(self: *Self) void {
        const text = self.buffer[0..self.total_len];
        if (parsing.parseSyllable(text)) |components| {
            self.initial_len = @intCast(components.initial_consonant.len);
            self.vowel_len = @intCast(components.vowel.len);
            self.final_len = @intCast(components.final_consonant.len);
        } else |_| {}
    }

    pub fn initialConsonant(self: *const Self) []const u8 {
        return self.buffer[0..self.initial_len];
    }

    pub fn vowel(self: *const Self) []const u8 {
        return self.buffer[self.initial_len .. self.initial_len + self.vowel_len];
    }

    pub fn vowelStartIdx(self: *const Self) usize {
        return self.initial_len;
    }
    pub fn finalConsonant(self: *const Self) []const u8 {
        const start = self.initial_len + self.vowel_len;
        return self.buffer[start .. start + self.final_len];
    }

    pub fn isEmpty(self: *const Self) bool {
        return self.total_len == 0;
    }

    pub fn addingLetterModifcation(self: *Self, entry: ModificationEntry) bool {
        if (self.letter_modification_len >= self.letter_modifications.len) return false;
        self.letter_modifications[self.letter_modification_len] = entry;
        self.letter_modification_len += 1;

        return true;
    }

    pub fn containsModification(self: *const Self, mod: LetterModification) bool {
        for (self.letter_modifications[0..self.letter_modification_len]) |entry| {
            if (entry.mod == mod) return true;
        }
        return false;
    }

    pub fn getModificationAt(self: *const Self, idx: usize) ?LetterModification {
        for (self.letter_modifications[0..self.letter_modification_len]) |entry| {
            if (entry.index == idx) return entry.mod;
        }
        return null;
    }

    pub fn removeModification(self: *Self, mod: LetterModification) void {
        var new_len: u2 = 0;
        for (self.letter_modifications[0..self.letter_modification_len]) |entry| {
            if (entry.mod != mod) {
                self.letter_modifications[new_len] = entry;
                new_len += 1;
            }
        }
        self.letter_modification_len = new_len;
    }

    pub fn removeModificationAt(self: *Self, idx: usize) void {
        var new_len: u8 = 0;
        for (self.letter_modifications[0..self.letter_modification_len]) |entry| {
            if (entry.index != idx) {
                self.letter_modifications[new_len] = entry;
                new_len += 1;
            }
        }
        self.letter_modification_len = new_len;
    }

    pub fn replaceModificationAt(self: *Self, idx: usize, new_mod: LetterModification) void {
        for (self.letter_modifications[0..self.letter_modification_len]) |*entry| {
            if (entry.index == idx) {
                entry.mod = new_mod;
                return;
            }
        }
    }

    pub fn getToneMarkIndex(self: *const Self) ?usize {
        if (self.vowel_len == 0) return null;

        const v = self.vowel();

        var relative_idx: usize = 0;

        switch (self.vowel_len) {
            1 => {
                relative_idx = 0;
            },
            2 => {
                // Kiểm tra âm đệm, chi tiết xem tại đây
                // https://vi.wikipedia.org/wiki/Quy_t%E1%BA%AFc_%C4%91%E1%BA%B7t_d%E1%BA%A5u_thanh_c%E1%BB%A7a_ch%E1%BB%AF_Qu%E1%BB%91c_ng%E1%BB%AF
                const is_medial = std.mem.eql(u8, v, "oa") or std.mem.eql(u8, v, "oe") or std.mem.eql(u8, v, "uy") or std.mem.eql(u8, v, "ue");

                if (is_medial) {
                    relative_idx = 1;
                } else if (self.final_len > 0) {
                    relative_idx = 1;
                } else {
                    relative_idx = 0;
                }
            },
            3 => {
                relative_idx = 1;
            },
            else => {
                relative_idx = 0;
            },
        }

        return self.vowelStartIdx() + relative_idx;
    }

    pub fn rendertoUtf8(self: *const Self, out_buffer: []u8) ![]u8 {
        var out_len: usize = 0;

        const tone_mark_idx = self.getToneMarkIndex();

        for (self.buffer[0..self.total_len], 0..) |base_char, i| {
            var codepoint: u21 = @as(u21, base_char);

            if (self.getModificationAt(i)) |mod| {
                codepoint = switch (mod) {
                    .Circumflex => char_map.getCircumflex(codepoint) orelse codepoint,
                    .Breve => char_map.getBreve(codepoint) orelse codepoint,
                    .Horn => char_map.getHorn(codepoint) orelse codepoint,
                    .Dyet => char_map.getDyet(codepoint) orelse codepoint,
                };
            }

            // Apply tone mark
            if (tone_mark_idx != null and tone_mark_idx.? == i) {
                if (self.tone_mark) |tone| {
                    codepoint = char_map.applyTone(codepoint, tone) orelse codepoint;
                }
            }

            // Encode to UTF-8
            var char_bytes: [4]u8 = undefined;
            const bytes_written = try std.unicode.utf8Encode(codepoint, &char_bytes);

            @memcpy(out_buffer[out_len .. out_len + bytes_written], char_bytes[0..bytes_written]);
            out_len += bytes_written;
        }

        return out_buffer[0..out_len];
    }
};
