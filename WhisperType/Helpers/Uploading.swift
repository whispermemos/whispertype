import Foundation

struct TranscriptionResult {
    let segmentTranscript: String
}

enum TranscriptionError: LocalizedError {
    case error(String)

    var errorDescription: String? {
        switch self {
        case .error(let message):
            return message
        }
    }
}

struct UploadOptions {
    let audioData: NSData
    let language: String
    let prompt: String?
}

private let groqTranscriptionsURL = URL(string: "https://api.groq.com/openai/v1/audio/transcriptions")!
private let groqModel = "whisper-large-v3"

private func makeUploadSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 5
    configuration.timeoutIntervalForResource = 5
    configuration.waitsForConnectivity = false
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    configuration.urlCache = nil
    configuration.httpCookieStorage = nil
    configuration.httpShouldSetCookies = false

    return URLSession(configuration: configuration)
}

func uploadRecording(options: UploadOptions) async throws -> TranscriptionResult {
    guard let apiKey = loadGroqApiKey() else {
        throw TranscriptionError.error("Add your Groq API key in Settings → API Key")
    }

    let maxAttempts = 2
    var lastError: Error?

    for attempt in 1...maxAttempts {
        do {
            return try await performUpload(options: options, apiKey: apiKey)
        } catch {
            lastError = error

            if attempt < maxAttempts {
                continue
            }
        }
    }

    throw lastError ?? TranscriptionError.error("Maximum retry attempts exceeded")
}

private func performUpload(options: UploadOptions, apiKey: String) async throws -> TranscriptionResult {
    let boundary = UUID().uuidString
    var request = URLRequest(url: groqTranscriptionsURL)
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = 5
    request.cachePolicy = .reloadIgnoringLocalCacheData
    request.assumesHTTP3Capable = false

    var fields = ["model": groqModel]
    if options.language != "auto" {
        fields["language"] = options.language
    }
    if let prompt = options.prompt {
        fields["prompt"] = prompt
    }

    request.httpBody = makeMultipartBody(
        boundary: boundary, fields: fields, audioData: options.audioData as Data)

    let session = makeUploadSession()
    defer {
        session.finishTasksAndInvalidate()
    }

    let data: Data
    let response: URLResponse
    do {
        (data, response) = try await session.data(for: request)
    } catch let error as NSError {
        if error.code == NSURLErrorTimedOut {
            throw TranscriptionError.error("Request timed out after 5 seconds")
        } else {
            throw TranscriptionError.error("Network error: \(error.localizedDescription)")
        }
    }

    guard let httpResponse = response as? HTTPURLResponse else {
        throw TranscriptionError.error("Invalid response from Groq")
    }

    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]

    if httpResponse.statusCode != 200 {
        let error = json?["error"] as? [String: Any]
        let errorMessage = error?["message"] as? String ?? "HTTP \(httpResponse.statusCode)"
        throw TranscriptionError.error("Groq error: \(errorMessage)")
    }

    guard let text = json?["text"] as? String else {
        throw TranscriptionError.error("Groq response missing transcript")
    }

    return TranscriptionResult(segmentTranscript: text.trimmingCharacters(in: .whitespacesAndNewlines))
}

private func makeMultipartBody(boundary: String, fields: [String: String], audioData: Data) -> Data {
    var body = Data()

    for (name, value) in fields {
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        body.append("\(value)\r\n")
    }

    body.append("--\(boundary)\r\n")
    body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n")
    body.append("Content-Type: audio/m4a\r\n\r\n")
    body.append(audioData)
    body.append("\r\n--\(boundary)--\r\n")

    return body
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}
