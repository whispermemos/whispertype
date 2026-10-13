//
//  Helpers.swift
//  WhisperType
//
//  Created by Vojtech Rinik on 23/02/2025.
//

import Foundation

public func post<T: Decodable>(url: URL, payload: [String: Any]) async throws -> T {
    let session = URLSession.shared

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: payload)

    let (data, response) = try await session.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
        throw APIError.invalidResponse
    }

    if httpResponse.statusCode != 200 {
        let errorResponse = try JSONDecoder().decode(APIErrorResponse.self, from: data)
        throw APIError.serverError(errorResponse.error)
    }

    let decodedResponse = try JSONDecoder().decode(T.self, from: data)
    return decodedResponse
}
