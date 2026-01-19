import Foundation
import SharedDomain

// MARK: - TransportMessage
// WCSession을 통해 송수신되는 메시지 타입
// Envelope<T>를 JSON으로 직렬화하여 전송
public struct TransportMessage: Codable, Equatable, Sendable {
    public let data: Data

    public init(data: Data) {
        self.data = data
    }

    // Envelope을 TransportMessage로 변환
    public init<T: Codable & Sendable>(envelope: Envelope<T>) throws {
        let encoder = JSONEncoder.transportEncoder
        self.data = try encoder.encode(envelope)
    }

    // TransportMessage에서 Envelope 디코딩
    public func decode<T: Codable & Sendable>() throws -> Envelope<T> {
        let decoder = JSONDecoder.transportDecoder
        return try decoder.decode(Envelope<T>.self, from: data)
    }

    // Dictionary 형식으로 변환 (WCSession 전송용)
    public func toDictionary() -> [String: Any] {
        return ["data": data]
    }

    // Dictionary에서 TransportMessage 생성
    public static func fromDictionary(_ dict: [String: Any]) -> TransportMessage? {
        guard let data = dict["data"] as? Data else { return nil }
        return TransportMessage(data: data)
    }
}
