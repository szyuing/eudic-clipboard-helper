#Requires AutoHotkey v2.0
#SingleInstance Force

SetWorkingDir(A_ScriptDir)

global DEBOUNCE_MS := 500
global SAME_WORD_WINDOW_MS := 1500
global MAX_LOOKUP_LENGTH := 80
global DEBUG_LOG_FILTERS := false
global LOG_FILE := A_ScriptDir "\EudicClipboardHelper.log"

global gLastRawClipboard := ""
global gLastTriggerTick := 0
global gLastWord := ""
global gLastWordTick := 0

OnClipboardChange(ClipboardChanged)

Log("Script started.")
return

ClipboardChanged(changeType) {
    global DEBOUNCE_MS, SAME_WORD_WINDOW_MS, MAX_LOOKUP_LENGTH, DEBUG_LOG_FILTERS
    global gLastRawClipboard, gLastTriggerTick, gLastWord, gLastWordTick

    ; Type 1 means text content in AutoHotkey v2.
    if (changeType != 1) {
        if (DEBUG_LOG_FILTERS) {
            Log("Skipped. reason=non_text changeType=" . changeType)
        }
        return
    }

    rawText := A_Clipboard

    if (rawText = gLastRawClipboard) {
        if (DEBUG_LOG_FILTERS) {
            Log("Skipped. reason=duplicate_raw raw=" . rawText)
        }
        return
    }
    gLastRawClipboard := rawText

    lookupText := NormalizeLookupText(rawText)
    if (lookupText = "") {
        if (DEBUG_LOG_FILTERS) {
            Log("Skipped. reason=empty_after_normalize raw=" . rawText)
        }
        return
    }

    if (StrLen(lookupText) > MAX_LOOKUP_LENGTH) {
        if (DEBUG_LOG_FILTERS) {
            Log("Skipped. reason=too_long normalized=" . lookupText)
        }
        return
    }

    ; Allow common English words, phrases, and trailing punctuation cleanup.
    if !IsSupportedLookupText(lookupText) {
        if (DEBUG_LOG_FILTERS) {
            Log("Skipped. reason=unsupported normalized=" . lookupText)
        }
        return
    }

    nowTick := A_TickCount

    if ((nowTick - gLastTriggerTick) < DEBOUNCE_MS) {
        if (DEBUG_LOG_FILTERS) {
            Log("Skipped. reason=debounced normalized=" . lookupText)
        }
        return
    }

    normalizedWord := StrLower(lookupText)
    if (normalizedWord = gLastWord && (nowTick - gLastWordTick) < SAME_WORD_WINDOW_MS) {
        if (DEBUG_LOG_FILTERS) {
            Log("Skipped. reason=same_lookup_window normalized=" . normalizedWord)
        }
        return
    }

    uri := "eudic://lp-dict/" . UrlEncode(lookupText)
    try {
        Run(uri)
        if (DEBUG_LOG_FILTERS) {
            Log("Triggered. normalized=" . lookupText . " uri=" . uri)
        }
        gLastTriggerTick := nowTick
        gLastWord := normalizedWord
        gLastWordTick := nowTick
    } catch Error as err {
        Log("Run failed. message=" . err.Message . " uri=" . uri)
    }
}

UrlEncode(value) {
    utf8Size := StrPut(value, "UTF-8")
    utf8 := Buffer(utf8Size)
    StrPut(value, utf8, "UTF-8")

    encoded := ""
    Loop utf8Size - 1 {
        code := NumGet(utf8, A_Index - 1, "UChar")
        if (
            (code >= 0x30 && code <= 0x39) ; 0-9
            || (code >= 0x41 && code <= 0x5A) ; A-Z
            || (code >= 0x61 && code <= 0x7A) ; a-z
            || code = 0x2D ; -
            || code = 0x2E ; .
            || code = 0x5F ; _
            || code = 0x7E ; ~
        ) {
            encoded .= Chr(code)
        } else {
            encoded .= "%" . Format("{:02X}", code)
        }
    }
    return encoded
}

NormalizeLookupText(text) {
    text := Trim(text)

    while (StrLen(text) > 0 && IsIgnorableEdgeChar(SubStr(text, 1, 1))) {
        text := SubStr(text, 2)
    }

    while (StrLen(text) > 0 && IsIgnorableEdgeChar(SubStr(text, -1))) {
        text := SubStr(text, 1, -1)
    }

    if (text = "") {
        return ""
    }

    normalized := ""
    previousWasSpace := false

    for _, ch in StrSplit(text) {
        if IsWhitespace(ch) {
            if (!previousWasSpace && normalized != "") {
                normalized .= " "
            }
            previousWasSpace := true
            continue
        }

        normalized .= ch
        previousWasSpace := false
    }

    if (SubStr(normalized, -1) = " ") {
        normalized := SubStr(normalized, 1, -1)
    }

    return normalized
}

IsSupportedLookupText(text) {
    prevWasLetter := false
    letterCount := 0

    for _, ch in StrSplit(text) {
        if IsAsciiLetter(ch) {
            prevWasLetter := true
            letterCount += 1
            continue
        }

        if ((ch = "'" || ch = Chr(0x2019) || ch = "-") && prevWasLetter) {
            prevWasLetter := false
            continue
        }

        if (ch = " " && prevWasLetter) {
            prevWasLetter := false
            continue
        }

        return false
    }

    return letterCount > 0 && prevWasLetter
}

IsIgnorableEdgeChar(ch) {
    if IsWhitespace(ch) {
        return true
    }

    for _, edgeChar in [",", ".", ";", ":", "!", "?", Chr(0x22), "'", Chr(0x2019), Chr(0x201C), Chr(0x201D), "(", ")", "[", "]", "{", "}", "<", ">"] {
        if (ch = edgeChar) {
            return true
        }
    }

    return false
}

IsAsciiLetter(ch) {
    code := Ord(ch)
    return (code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A)
}

IsWhitespace(ch) {
    return ch = " " || ch = "`t" || ch = "`r" || ch = "`n"
}

Log(message) {
    global LOG_FILE
    timestamp := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
    line := timestamp . " " . message . "`r`n"
    try {
        FileAppend(line, LOG_FILE, "UTF-8")
    } catch {
        ; Stay silent on logging failures.
    }
}
