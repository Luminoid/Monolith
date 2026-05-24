import Foundation
import Testing
@testable import MonolithLib

struct PlatformTests {
    @Test
    func `parseList accepts canonical names`() {
        let result = Platform.parseList("iPhone,iPad,macCatalyst")
        #expect(result == Set([.iPhone, .iPad, .macCatalyst]))
    }

    @Test
    func `parseList is case-insensitive`() {
        let result = Platform.parseList("IPHONE,ipad,MACCATALYST")
        #expect(result == Set([.iPhone, .iPad, .macCatalyst]))
    }

    @Test
    func `parseList accepts mac and catalyst aliases for macCatalyst`() {
        #expect(Platform.parseList("mac") == Set([.macCatalyst]))
        #expect(Platform.parseList("catalyst") == Set([.macCatalyst]))
    }

    @Test
    func `parseList trims whitespace around tokens`() {
        let result = Platform.parseList("  iPhone , iPad ")
        #expect(result == Set([.iPhone, .iPad]))
    }

    @Test
    func `parseList defaults to iPhone when nothing parses`() {
        // Unrecognized tokens emit stderr warnings and are skipped; the
        // fallback prevents downstream validation from receiving an empty
        // platform set (a Lumi app always at least targets iPhone).
        let result = Platform.parseList("typo,nonsense")
        #expect(result == Set([.iPhone]))
    }

    @Test
    func `parseList ignores unknown tokens but keeps valid ones`() {
        let result = Platform.parseList("iPhone,android,iPad")
        #expect(result == Set([.iPhone, .iPad]))
    }
}
