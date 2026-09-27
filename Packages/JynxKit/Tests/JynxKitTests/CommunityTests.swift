import Foundation
import Testing
@testable import JynxKit

@Test func everyLinkSet() throws {
    let c = try JSON.decoder().decode(CommunityReply.self, from: fixture("community")).community
    #expect(c.emailURL?.absoluteString == "mailto:support@justsal.xyz")
    #expect(c.telegramURL?.absoluteString == "https://t.me/jynx_support")
    #expect(c.channelURL?.absoluteString == "https://t.me/jynx_results")
    #expect(c.socials.map(\.0) == [.youtube, .instagram, .facebook, .x])
    #expect(c.socials.last?.1.absoluteString == "https://x.com/jynx")
    #expect(c.faq == [.init(q: "How do signals work?", a: "The team posts each trade in your channel.")])
}

@Test func nothingSetHidesTheLinksButKeepsTheFAQ() throws {
    let c = try JSON.decoder().decode(CommunityReply.self, from: fixture("community-empty")).community
    #expect(c.emailURL == nil && c.telegramURL == nil && c.channelURL == nil)
    #expect(c.socials.isEmpty)
    #expect(c.faq.count >= 4)
}
