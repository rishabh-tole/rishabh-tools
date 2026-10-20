import RishabhFCCore

func textTests() {
    test("csv to tsv handles quotes and embedded commas") {
        let csv = "name,note\n\"Smith, J\",\"said \"\"hi\"\"\"\nplain,x\n"
        expectEqual(TextConvert.csvToTSV(csv), "name\tnote\nSmith, J\tsaid \"hi\"\nplain\tx\n")
    }

    test("tsv to csv quotes only when needed") {
        expectEqual(TextConvert.tsvToCSV("a\tb, c\nsay \"x\"\td\n"), "a,\"b, c\"\n\"say \"\"x\"\"\",d\n")
    }

    test("csv keeps quoted newlines inside one row") {
        expectEqual(TextConvert.parseCSV("a,\"line1\nline2\"\nb,c"), [["a", "line1\nline2"], ["b", "c"]])
    }

    let srt = """
    1
    00:00:01,000 --> 00:00:02,500
    Hello <i>there</i>

    2
    00:00:03,000 --> 00:00:04,000
    Second line
    continues

    """

    test("srt to vtt") {
        expectEqual(TextConvert.srtToVTT(srt), """
        WEBVTT

        00:00:01.000 --> 00:00:02.500
        Hello <i>there</i>

        00:00:03.000 --> 00:00:04.000
        Second line
        continues

        """)
    }

    test("vtt to srt numbers cues, adds hours and drops settings and notes") {
        let vtt = """
        WEBVTT

        NOTE written by hand

        intro
        00:01.000 --> 00:02.500 align:start
        Hi

        01:00:03.000 --> 01:00:04.000
        Bye
        """
        expectEqual(TextConvert.vttToSRT(vtt), """
        1
        00:00:01,000 --> 00:00:02,500
        Hi

        2
        01:00:03,000 --> 01:00:04,000
        Bye

        """)
    }

    test("subtitles to plain text keeps only the spoken lines") {
        expectEqual(TextConvert.subtitleText(srt), "Hello there\nSecond line\ncontinues\n")
    }
}
