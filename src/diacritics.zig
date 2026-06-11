const MAX_WORLD_LENGTH = 7; // Maximum length of a Vietnamese word is 7 letters long (nghiêng)

pub const ToneMark = enum {
    // Dấu sắc (acute accent) - rising tone
    Acute,
    // Dấu huyền (grave accent) - falling tone
    Grave,
    // Dấu hỏi (hook above) - dipping tone
    HookAbove,
    // Dấu ngã (tilde) - creaky rising tone
    Tilde,
    // Dấu nặng (dot below) - creaky falling tone
    Underdot,
};

pub const LetterModification = enum {
    /// The circumflex (ˆ) diacritic - changes a, e, o to â, ê, ô
    Circumflex,
    /// The breve (˘) diacritic - changes a to ă
    Breve,
    /// The horn diacritic - changes o, u to ơ, ư
    Horn,
    /// The stroke through d - changes d to đ
    Dyet,
};

pub const ModificationEntry = struct {
    index: usize,
    mod: LetterModification,
};
