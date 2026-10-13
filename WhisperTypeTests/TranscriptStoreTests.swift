import XCTest
@testable import WhisperType

final class TranscriptStoreTests: XCTestCase {
    var store: TranscriptStore!
    
    override func setUp() {
        super.setUp()
        store = TranscriptStore()
    }
    
    override func tearDown() {
        store = nil
        super.tearDown()
    }
    
    func testGetParagraphsWithManualParagraphs() {
        store.addTranscript(number: 0, transcript: "hello")
        store.addTranscript(number: 1, transcript: "world")
        store.addTranscript(number: 2, transcript: "this is")
        store.addTranscript(number: 3, transcript: "a new paragraph")
        
        store.addParagraphAt(1)
        
        // Get paragraphs
        let paragraphs = store.getParagraphs()
        
        XCTAssertEqual(paragraphs.count, 2)
        XCTAssertEqual(paragraphs[0], "Hello world.")
        XCTAssertEqual(paragraphs[1], "This is a new paragraph.")
    }
}
