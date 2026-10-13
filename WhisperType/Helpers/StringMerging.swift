import Foundation

// CleanedString.swift
struct CleanedString {
    struct Mapping {
        let clean: String
        var original: String
    }

    let mappings: [Mapping]

    static func process(input: String) -> CleanedString {
        // Normalize whitespace to single spaces and trim
        let normalizedInput = input.replacingOccurrences(
            of: "\\s+", with: " ", options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        var mappings: [Mapping] = []
        var initialPunctuation = ""

        for char in normalizedInput {
            let lower = String(char).lowercased()
            let isAllowed = lower.range(of: "[\\w\\s]", options: .regularExpression) != nil

            if isAllowed {
                mappings.append(
                    Mapping(
                        clean: lower,
                        original: initialPunctuation + String(char)
                    )
                )
                initialPunctuation = ""
            } else if mappings.count > 0 {
                mappings[mappings.count - 1].original += String(char)
            } else {
                initialPunctuation += String(char)
            }
        }

        return CleanedString(mappings: mappings)
    }

    var cleaned: String {
        return mappings.map { $0.clean }.joined()
    }

    var original: String {
        return mappings.map { $0.original }.joined()
    }

    var size: Int {
        return mappings.reduce(0) { acc, mapping in
            acc + mapping.clean.count
        }
    }

    var debugString: String {
        var lines: [String] = []
        var cleanLine = ""
        var originalLine = ""

        for mapping in mappings {
            let cleanPart = mapping.clean
            let originalPart = mapping.original

            // Calculate how many characters in original are not in clean (punctuation)
            let extraChars = originalPart.count - cleanPart.count

            cleanLine += cleanPart + String(repeating: "_", count: extraChars)
            originalLine += originalPart
        }

        lines.append(cleanLine)
        lines.append(originalLine)

        return lines.joined(separator: "\n")
    }

    func prefix(_ length: Int) -> CleanedString {
        if length <= 0 {
            return CleanedString(mappings: [])
        } else if length >= mappings.count {
            return CleanedString(mappings: mappings)
        } else {
            return CleanedString(mappings: Array(mappings[0..<length]))
        }
    }

    func suffix(_ length: Int) -> CleanedString {
        if length <= 0 {
            return CleanedString(mappings: [])
        } else if length >= mappings.count {
            return CleanedString(mappings: mappings)
        } else {
            return CleanedString(mappings: Array(mappings[(mappings.count - length)...]))
        }
    }

    func calculateSimilarity(other: CleanedString) -> Double {
        let str1 = self.cleaned
        let str2 = other.cleaned

        // Handle edge cases
        if str1.isEmpty && str2.isEmpty { return 1.0 }
        if str1.isEmpty || str2.isEmpty { return 0.0 }
        if str1.count <= 1 || str2.count <= 1 { return 0.0 }

        // Calculate Levenshtein distance
        let distance = str1.levenshteinDistance(to: str2)
        
        // Convert distance to similarity ratio (0-1)
        // The maximum possible distance is the length of the longer string
        let maxDistance = max(str1.count, str2.count)
        
        // Calculate similarity as 1 - (distance / maxDistance)
        // This gives 1.0 for identical strings and approaches 0.0 as differences increase
        return 1.0 - (Double(distance) / Double(maxDistance))
    }
}

// merge.swift
func merge(leftString: String, rightString: String) -> String {
    let left = CleanedString.process(input: leftString)
    let right = CleanedString.process(input: rightString)

    let shorterLength = min(left.size, right.size)

    var highestSimilarity = 0.0
    var bestAmount = 0

    for amount in stride(from: shorterLength - 1, through: 1, by: -1) {
        let leftBit = left.suffix(amount)
        let rightBit = right.prefix(amount)
        let similarity = leftBit.calculateSimilarity(other: rightBit)

        if similarity > highestSimilarity {
            highestSimilarity = similarity
            bestAmount = amount
        }
    }

    if highestSimilarity > 0.8 {
        let amount = bestAmount
        let leftBit = left.suffix(amount)
        let rightBit = right.prefix(amount)

        let leftPortion = left.prefix(left.size - amount)
        let rightPortion = right.suffix(right.size - amount)

        let midpoint = Int(floor(Double(amount) / 2.0))
        let leftOverlap = leftBit.prefix(midpoint)
        let rightOverlap = rightBit.suffix(amount - midpoint)

        let sentence =
            leftPortion.original + leftOverlap.original + rightOverlap.original
            + rightPortion.original

        return sentence
    } else {
        return left.original + " " + right.original
    }
}

/// Merges an array of strings together by finding overlapping content between consecutive strings.
/// - Parameter strings: An array of strings to be merged
/// - Returns: A single merged string containing all content with overlaps handled
func mergeAll(strings: [String]) -> String {
    guard !strings.isEmpty else { return "" }
    guard strings.count > 1 else { return strings[0] }

    var result = strings[0]

    for i in 1..<strings.count {
        result = merge(leftString: result, rightString: strings[i])
   
    }

    return result
}
