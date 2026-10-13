//
//  Types.swift
//  WhisperType
//
//  Created by Vojtech Rinik on 23/02/2025.
//

enum APIError: Error, CustomStringConvertible {
    case invalidResponse
    case serverError(String)

    var description: String {
        switch self {
        case .invalidResponse:
            return "Invalid response from server."
        case .serverError(let message):
            return message
        }
    }
}

struct APIErrorResponse: Codable {
    let success: Bool
    let error: String
}
