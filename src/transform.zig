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
    if (syllable.isEmpty() and syllable.charsLen() > MAX_WORLD_LENGTH) {
        return Transformation.Ignored;
    }

    if (syllable.vowel() == undefined) {
        return Transformation.Ignored;
    }

    if (syllable.tone_mark) |existing_tone_mark| {
        if (existing_tone_mark == tone_mark) {
            syllable.tone_mark = null;
            return Transformation.ToneMarkRemoved;
        } else {
            syllable.tone_mark = tone_mark;
            return Transformation.ToneMarkReplaced;
        }
    } else {
        syllable.tone_mark = tone_mark;
        return Transformation.ToneMarkAdded;
    }
}

pub fn removeTone(input: *TransformSyllable) Transformation {
    if (input.charsLen() > MAX_WORLD_LENGTH) {
        return Transformation.Ignored;
    }

    if (input.tone_mark != null) {
        input.tone_mark = null;
        return Transformation.ToneMarkRemoved;
    }

    return Transformation.Ignored;
}

pub fn modifyLetter(syllable: *TransformSyllable, letter_modification: *LetterModification) Transformation {}
