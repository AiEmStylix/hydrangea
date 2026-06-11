const syllable = @import("syllable.zig");
const diacritics = @import("diacritics.zig");
const TransformSyllable = syllable.TransformSyllable;
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

pub fn addTone(transformSyllable: *TransformSyllable, tone_mark: ToneMark) Transformation {
    if (transformSyllable.isEmpty() and transformSyllable.charsLen() > MAX_WORLD_LENGTH) {
        return Transformation.Ignored;
    }

    if (transformSyllable.vowel() == undefined) {
        return Transformation.Ignored;
    }

    if (transformSyllable.tone_mark) |existing_tone_mark| {
        if (existing_tone_mark == tone_mark) {
            transformSyllable.tone_mark = null;
            return Transformation.ToneMarkRemoved;
        } else {
            transformSyllable.tone_mark = tone_mark;
            return Transformation.ToneMarkReplaced;
        }
    } else {
        transformSyllable.tone_mark = tone_mark;
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
