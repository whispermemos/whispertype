//
//  String.swift
//  WhisperType
//
//  Created by Vojtech Rinik on 27/02/2025.
//

import Foundation

extension String {
    /// Calculates the Levenshtein distance between this string and another string.
    /// - Parameter other: The string to compare with.
    /// - Returns: The minimum number of single-character edits (insertions, deletions, or substitutions)
    ///   required to change this string into the other string.
    public func levenshteinDistance(to other: String) -> Int {
        // Handle edge cases
        if self == other { return 0 }
        if self.isEmpty { return other.count }
        if other.isEmpty { return self.count }
        
        // Convert strings to arrays for easier indexing
        let selfChars = Array(self)
        let otherChars = Array(other)
        
        // Create a matrix to store the distances
        // matrix[i][j] will represent the distance between
        // the first i characters of self and the first j characters of other
        var matrix = Array(repeating: Array(repeating: 0, count: otherChars.count + 1),
                           count: selfChars.count + 1)
        
        // Initialize the first row and column
        for i in 0...selfChars.count {
            matrix[i][0] = i
        }
        
        for j in 0...otherChars.count {
            matrix[0][j] = j
        }
        
        // Fill in the rest of the matrix
        for i in 1...selfChars.count {
            for j in 1...otherChars.count {
                let cost = selfChars[i-1] == otherChars[j-1] ? 0 : 1
                
                matrix[i][j] = Swift.min(
                    matrix[i-1][j] + 1,      // Deletion
                    matrix[i][j-1] + 1,      // Insertion
                    matrix[i-1][j-1] + cost  // Substitution
                )
            }
        }
        
        // The bottom-right cell contains the Levenshtein distance
        return matrix[selfChars.count][otherChars.count]
    }
}

// Example usage:
// let source = "kitten"
// let target = "sitting"
// let distance = source.levenshteinDistance(to: target)
// print(distance) // Outputs: 3
