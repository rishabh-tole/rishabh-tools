import RishabhFCCore

private let all = Encoders(ffmpeg: true, cwebp: true)
private let none = Encoders()

private func ids(_ choices: [Choice]) -> [String] { choices.map(\.id) }
private func file(_ name: String) -> Item { Item(name: name, isDirectory: false) }

func catalogTests() {
    test("normalizes extensions, including double ones") {
        expectEqual(Catalog.normalizedExtension(of: "Photo.JPEG"), "jpg")
        expectEqual(Catalog.normalizedExtension(of: "a.b.tif"), "tiff")
        expectEqual(Catalog.normalizedExtension(of: "backup.tar.gz"), "tar.gz")
        expectEqual(Catalog.normalizedExtension(of: "backup.tgz"), "tar.gz")
        expectEqual(Catalog.normalizedExtension(of: "Makefile"), "")
    }

    test("classifies by extension") {
        expectEqual(Catalog.kind(of: file("a.heic")), .image)
        expectEqual(Catalog.kind(of: file("a.mkv")), .video)
        expectEqual(Catalog.kind(of: file("a.opus")), .audio)
        expectEqual(Catalog.kind(of: file("a.pdf")), .pdf)
        expectEqual(Catalog.kind(of: file("a.docx")), .document)
        expectEqual(Catalog.kind(of: file("a.tsv")), .table)
        expectEqual(Catalog.kind(of: file("a.vtt")), .subtitle)
        expectEqual(Catalog.kind(of: file("a.tar.gz")), .archive)
        expectEqual(Catalog.kind(of: Item(name: "Photos", isDirectory: true)), .folder)
        expectEqual(Catalog.kind(of: file("a.xyz")), .other)
    }

    test("image wheel drops the source format and puts the next one in the center") {
        expectEqual(ids(Catalog.choices(.convert, for: [file("a.jpg")], encoders: all)),
                    ["png", "webp", "heic", "tiff", "avif", "bmp", "pdf"])
        expectEqual(ids(Catalog.choices(.convert, for: [file("a.png")], encoders: all)).first, "jpg")
    }

    test("webp needs an encoder") {
        expect(!ids(Catalog.choices(.convert, for: [file("a.jpg")], encoders: none)).contains("webp"))
        let cwebpOnly = Encoders(ffmpeg: false, cwebp: true)
        expect(ids(Catalog.choices(.convert, for: [file("a.jpg")], encoders: cwebpOnly)).contains("webp"))
    }

    test("audio wheel matches tangerine's wav wheel") {
        expectEqual(ids(Catalog.choices(.convert, for: [file("a.wav")], encoders: all)),
                    ["mp3", "m4a", "flac", "ogg", "opus", "aiff", "wma"])
    }

    test("audio without ffmpeg falls back to afconvert formats") {
        expectEqual(ids(Catalog.choices(.convert, for: [file("a.mp3")], encoders: none)),
                    ["m4a", "wav", "flac", "aiff"])
        expectEqual(Catalog.choices(.convert, for: [file("a.ogg")], encoders: none), [])
    }

    test("video without ffmpeg only offers AVFoundation outputs for readable sources") {
        expectEqual(ids(Catalog.choices(.convert, for: [file("a.mov")], encoders: none)), ["mp4", "gif", "m4a"])
        expectEqual(Catalog.choices(.convert, for: [file("a.mkv")], encoders: none), [])
        expect(ids(Catalog.choices(.convert, for: [file("a.mkv")], encoders: all)).contains("mp3"))
    }

    test("documents, pdf, tables, subtitles, archives") {
        expectEqual(ids(Catalog.choices(.convert, for: [file("a.pdf")], encoders: none)),
                    ["docx", "jpg", "png", "txt", "rtf", "html"])
        expectEqual(ids(Catalog.choices(.convert, for: [file("a.md")], encoders: none)).first, "pdf")
        expectEqual(ids(Catalog.choices(.convert, for: [file("a.csv")], encoders: none)), ["tsv"])
        expectEqual(ids(Catalog.choices(.convert, for: [file("a.srt")], encoders: none)), ["vtt", "txt"])
        expectEqual(ids(Catalog.choices(.convert, for: [file("a.zip")], encoders: none)), ["extract", "tar.gz"])
        expectEqual(ids(Catalog.choices(.convert, for: [file("a.tar")], encoders: none)), ["extract", "zip"])
    }

    test("folders and unknown files can be archived") {
        expectEqual(ids(Catalog.choices(.convert, for: [Item(name: "dir", isDirectory: true)], encoders: none)),
                    ["zip", "tar.gz"])
        expectEqual(ids(Catalog.choices(.convert, for: [file("notes.xyz")], encoders: none)), ["zip"])
    }

    test("a selection gets the formats every file shares") {
        let mixed = [file("a.jpg"), file("b.png")]
        expectEqual(ids(Catalog.choices(.convert, for: mixed, encoders: none)),
                    ["heic", "tiff", "avif", "bmp", "pdf", "zip"])
        expectEqual(ids(Catalog.choices(.convert, for: [file("a.jpg"), file("b.mp3")], encoders: all)), ["zip"])
    }

    test("tools depend on the kind and the selection") {
        expectEqual(ids(Catalog.choices(.tools, for: [file("a.jpg")], encoders: none)),
                    ["compress", "metadata", "resize", "rotate"])
        expectEqual(ids(Catalog.choices(.tools, for: [file("a.jpg"), file("b.heic")], encoders: none)),
                    ["compress", "metadata", "resize", "rotate", "combine"])
        expectEqual(ids(Catalog.choices(.tools, for: [file("a.pdf"), file("b.pdf")], encoders: none)),
                    ["compress", "split", "merge"])
        expectEqual(ids(Catalog.choices(.tools, for: [file("a.mov")], encoders: none)), ["compress", "mute"])
        expectEqual(Catalog.choices(.tools, for: [file("a.txt")], encoders: none), [])
    }

    test("file actions work on anything") {
        expectEqual(ids(Catalog.choices(.actions, for: [Item(name: "dir", isDirectory: true)], encoders: none)),
                    ["airdrop", "float", "copy", "move", "copypath", "terminal"])
    }
}
