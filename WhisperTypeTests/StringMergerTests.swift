//
//  StringMergerTests.swift
//  WhisperType
//
//  Created by Vojtech Rinik on 26/02/2025.
//

import XCTest

@testable import WhisperType

class StringMergerTests: XCTestCase {

    func testMergeOverlappingStrings() {
        // Setup
        let string1 = "This is a test sentence with some overlap."
        let string2 = "with some overlap and additional content."

        // Execute
        let result = merge(leftString: string1, rightString: string2)

        // Verify
        XCTAssertEqual(result, "This is a test sentence with some overlap and additional content.")
    }

    func testMergeOverlappingStringsWithParagraphBug() {
        // Setup
        let string1 =
            "Now when we get the transcription back, it's composed back together by running an algorithm which detects overlapping text. And it kind of merges transcribed blocks, even though there's a bit of overlap on the edges of it."
        let string2 =
            "and it kind of merges transcribed blocks even though there's a bit of overlap on the edges of it. However, I found a bug with this implementation. You'll notice that I also have a feature to create new paragraphs manually and sometimes when I use this feature I get repeated text. So there's some and Reflect."

        // Execute
        let result = merge(leftString: string1, rightString: string2)

        // Verify
        XCTAssertEqual(
            result,
            "Now when we get the transcription back, it's composed back together by running an algorithm which detects overlapping text. And it kind of merges transcribed blocks, even though there's a bit of overlap on the edges of it. However, I found a bug with this implementation. You'll notice that I also have a feature to create new paragraphs manually and sometimes when I use this feature I get repeated text. So there's some and Reflect."
        )
    }

    func testMergeOverlappingStringsWithRepeatedSentence() {
        // Setup
        let string1 =
            "But why would you have it otherwise? Real prayer is about change and change is never easy."
        let string2 =
            "A real prayer is about change, and change is never easy. But there's nothing complicated or mysterious about making the examen part of your life."

        // Execute
        let result = merge(leftString: string1, rightString: string2)

        // Verify
        XCTAssertEqual(
            result,
            "But why would you have it otherwise? Real prayer is about change, and change is never easy. But there's nothing complicated or mysterious about making the examen part of your life."
        )
    }
}
