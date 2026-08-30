import Foundation
import Testing
@testable import FilmStudioCore

struct CaptionParserTests {
    @Test func parsesSubRip() {
        let srt = """
        1
        00:00:01,000 --> 00:00:04,200
        The relay answers.

        2
        00:00:05,000 --> 00:00:07,000
        Two lines
        of caption.
        """
        let cues = CaptionParser.parse(srt)

        #expect(cues.count == 2)
        #expect(cues[0].startSeconds == 1.0)
        #expect(cues[0].endSeconds == 4.2)
        #expect(cues[0].text == "The relay answers.")
        #expect(cues[1].text == "Two lines\nof caption.")
    }

    @Test func parsesWebVTTWithHeaderNotesSettingsAndTags() {
        let vtt = """
        WEBVTT

        NOTE This block is commentary, not a cue.

        00:01.000 --> 00:04.000 align:center
        <v Mara>Storm's <i>coming</i>.</v>

        1:00:00.500 --> 1:00:02.000
        An hour in.
        """
        let cues = CaptionParser.parse(vtt)

        #expect(cues.count == 2)
        #expect(cues[0].startSeconds == 1.0)
        #expect(cues[0].endSeconds == 4.0)
        #expect(cues[0].text == "Storm's coming.")
        #expect(cues[1].startSeconds == 3600.5)
    }

    @Test func skipsMalformedBlocksAndEmptyFiles() {
        #expect(CaptionParser.parse("").isEmpty)
        #expect(CaptionParser.parse("no timing here\njust text").isEmpty)
        let mixed = """
        garbage --> also garbage
        text

        00:00:01,000 --> 00:00:02,000
        Survives.
        """
        let cues = CaptionParser.parse(mixed)
        #expect(cues.count == 1)
        #expect(cues[0].text == "Survives.")
    }
}
