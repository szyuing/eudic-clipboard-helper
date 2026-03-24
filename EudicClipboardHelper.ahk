#Requires AutoHotkey v2.0
#SingleInstance Force

SetWorkingDir(A_ScriptDir)

global DEBOUNCE_MS := 500
global SAME_WORD_WINDOW_MS := 1500
global MAX_WORD_LENGTH := 40
global LOG_FILE := A_ScriptDir "\EudicClipboardHelper.log"

global gLastRawClipboard := ""
global gLastTriggerTick := 0
global gLastWord := ""
global gLastWordTick := 0

OnClipboardChange(ClipboardChanged)

Log("Script started.")
return

ClipboardChanged(changeType) {
    global DEBOUNCE_MS, SAME_WORD_WINDOW_MS, MAX_WORD_LENGTH
    global gLastRawClipboard, gLastTriggerTick, gLastWord, gLastWordTick

    ; Type 1 means text content in AutoHotkey v2.
    if (changeType != 1) {
        return
    }

    rawText := A_Clipboard

    if (rawText = gLastRawClipboard) {
        return
    }
    gLastRawClipboard := rawText

    word := Trim(rawText)
    if (word = "") {
        return
    }

    if (StrLen(word) > MAX_WORD_LENGTH) {
        return
    }

    if !RegExMatch(word, "^[A-Za-z]+$") {
        return
    }

    nowTick := A_TickCount

    if ((nowTick - gLastTriggerTick) < DEBOUNCE_MS) {
        return
    }

    normalizedWord := StrLower(word)
    if (normalizedWord = gLastWord && (nowTick - gLastWordTick) < SAME_WORD_WINDOW_MS) {
        return
    }

    uri := "eudic://lp-dict/" . UrlEncode(word)
    try {
        Run(uri)
        gLastTriggerTick := nowTick
        gLastWord := normalizedWord
        gLastWordTick := nowTick
    } catch Error as err {
        Log("Run failed. message=" . err.Message . " uri=" . uri)
    }
}

UrlEncode(value) {
    encoded := ""
    for _, ch in StrSplit(value) {
        code := Ord(ch)
        if (
            (code >= 0x30 && code <= 0x39) ; 0-9
            || (code >= 0x41 && code <= 0x5A) ; A-Z
            || (code >= 0x61 && code <= 0x7A) ; a-z
            || code = 0x2D ; -
            || code = 0x2E ; .
            || code = 0x5F ; _
            || code = 0x7E ; ~
        ) {
            encoded .= ch
        } else {
            encoded .= "%" . Format("{:02X}", code)
        }
    }
    return encoded
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
