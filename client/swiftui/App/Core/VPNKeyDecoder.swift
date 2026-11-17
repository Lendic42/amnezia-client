import Foundation
import Compression

enum VPNKeyDecodingError: Error {
    case invalidBase64
    case invalidDecompression
}

struct VPNKeyDecoder {
    static func decode(_ key: String) throws -> Data {
        var payload = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if payload.hasPrefix("vpn://") {
            payload.removeFirst("vpn://".count)
        }
        guard let bytes = Data(base64URLDecoded: payload) else {
            throw VPNKeyDecodingError.invalidBase64
        }
        if let decompressed = try? decompressZlib(bytes) {
            return decompressed
        }
        return bytes
    }

    static func decodeJSON(_ key: String) throws -> Any {
        let data = try decode(key)
        return try JSONSerialization.jsonObject(with: data)
    }

    static func decompress(_ data: Data) throws -> Data {
        return try decompressZlib(data)
    }

    private static func decompressZlib(_ data: Data) throws -> Data {
        var output = Data()
        let chunkSize = 64 * 1024
        var chunk = [UInt8](repeating: 0, count: chunkSize)
        var stream = compression_stream()
        var status = compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB)
        guard status != COMPRESSION_STATUS_ERROR else {
            throw VPNKeyDecodingError.invalidDecompression
        }
        defer { compression_stream_destroy(&stream) }
        try data.withUnsafeBytes { input in
            guard let base = input.baseAddress else {
                throw VPNKeyDecodingError.invalidDecompression
            }
            stream.src_ptr = base.assumingMemoryBound(to: UInt8.self)
            stream.src_size = data.count
            try chunk.withUnsafeMutableBufferPointer { chunkBuffer in
                guard let dstBase = chunkBuffer.baseAddress else {
                    throw VPNKeyDecodingError.invalidDecompression
                }
                repeat {
                    stream.dst_ptr = dstBase
                    stream.dst_size = chunkSize
                    status = compression_stream_process(&stream, 0)
                    let produced = chunkSize - stream.dst_size
                    if produced > 0 {
                        output.append(dstBase, count: produced)
                    }
                } while status == COMPRESSION_STATUS_OK
            }
        }
        guard status == COMPRESSION_STATUS_END else {
            throw VPNKeyDecodingError.invalidDecompression
        }
        return output
    }
}

extension Data {
    init?(base64URLDecoded string: String) {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        self.init(base64Encoded: base64)
    }
}
