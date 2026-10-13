//
//  StringTests.swift
//  WhisperType
//
//  Created by Vojtech Rinik on 27/02/2025.
//

import XCTest
import WhisperType

final class StringTests: XCTestCase {
    
    // MARK: - Levenshtein Distance Tests
    
    func testLevenshteinDistanceIdenticalStrings() {
        // When strings are identical, distance should be 0
        XCTAssertEqual("hello".levenshteinDistance(to: "hello"), 0)
        XCTAssertEqual("".levenshteinDistance(to: ""), 0)
        XCTAssertEqual("swift".levenshteinDistance(to: "swift"), 0)
    }
    
    func testLevenshteinDistanceEmptyStrings() {
        // When one string is empty, distance should be the length of the other string
        XCTAssertEqual("".levenshteinDistance(to: "hello"), 5)
        XCTAssertEqual("swift".levenshteinDistance(to: ""), 5)
    }
    
    func testLevenshteinDistanceSimpleSubstitution() {
        // Single character substitution
        XCTAssertEqual("a".levenshteinDistance(to: "b"), 1)
        XCTAssertEqual("cat".levenshteinDistance(to: "bat"), 1)
        XCTAssertEqual("dog".levenshteinDistance(to: "fog"), 1)
    }
    
    func testLevenshteinDistanceInsertion() {
        // Single character insertion
        XCTAssertEqual("cat".levenshteinDistance(to: "cats"), 1)
        XCTAssertEqual("fog".levenshteinDistance(to: "frog"), 1)
    }
    
    func testLevenshteinDistanceDeletion() {
        // Single character deletion
        XCTAssertEqual("cats".levenshteinDistance(to: "cat"), 1)
        XCTAssertEqual("swift".levenshteinDistance(to: "swif"), 1)
    }
    
    func testLevenshteinDistanceMultipleOperations() {
        // Classic examples that require multiple operations
        XCTAssertEqual("kitten".levenshteinDistance(to: "sitting"), 3)
        XCTAssertEqual("saturday".levenshteinDistance(to: "sunday"), 3)
    }
    
    func testLevenshteinDistanceCompletelyDifferentStrings() {
        // Completely different strings
        XCTAssertEqual("abc".levenshteinDistance(to: "xyz"), 3)
    }
    
    func testLevenshteinDistanceCaseSensitivity() {
        // Ensure case sensitivity is respected
        XCTAssertEqual("Hello".levenshteinDistance(to: "hello"), 1)
        XCTAssertEqual("SWIFT".levenshteinDistance(to: "swift"), 5)
    }
    
    func testLevenshteinDistanceSpecialCharacters() {
        // Test with special characters and spaces
        XCTAssertEqual("hello world".levenshteinDistance(to: "hello-world"), 1)
        XCTAssertEqual("$100".levenshteinDistance(to: "$200"), 1)
        XCTAssertEqual("😀😁".levenshteinDistance(to: "😀😂"), 1)
    }
    
    func testLevenshteinDistancePerformance() {
        // Performance test for longer strings
        measure {
            let longString1 = String(repeating: "abcdefghij", count: 100)
            let longString2 = String(repeating: "abcdefghik", count: 100)
            _ = longString1.levenshteinDistance(to: longString2)
        }
    }
    
    // MARK: - Setup and Teardown
    
    override func setUp() {
        super.setUp()
        // Add any setup code here if needed
    }
    
    override func tearDown() {
        // Add any teardown code here if needed
        super.tearDown()
    }
    
    static var allTests = [
        ("testLevenshteinDistanceIdenticalStrings", testLevenshteinDistanceIdenticalStrings),
        ("testLevenshteinDistanceEmptyStrings", testLevenshteinDistanceEmptyStrings),
        ("testLevenshteinDistanceSimpleSubstitution", testLevenshteinDistanceSimpleSubstitution),
        ("testLevenshteinDistanceInsertion", testLevenshteinDistanceInsertion),
        ("testLevenshteinDistanceDeletion", testLevenshteinDistanceDeletion),
        ("testLevenshteinDistanceMultipleOperations", testLevenshteinDistanceMultipleOperations),
        ("testLevenshteinDistanceCompletelyDifferentStrings", testLevenshteinDistanceCompletelyDifferentStrings),
        ("testLevenshteinDistanceCaseSensitivity", testLevenshteinDistanceCaseSensitivity),
        ("testLevenshteinDistanceSpecialCharacters", testLevenshteinDistanceSpecialCharacters),
        ("testLevenshteinDistancePerformance", testLevenshteinDistancePerformance)
    ]
}
