import Foundation
import Compression

enum VPNKeyEncoder {
    static func encode(json: String) throws -> String {
        guard let data = json.data(using: .utf8) else {
            throw VPNKeyDecodingError.invalidDecompression
        }
        let compressed = try compressZlib(data)
        let base64url = compressed.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "vpn://" + base64url
    }

    static func compressZlib(_ data: Data) throws -> Data {
        var output = Data()
        let chunkSize = 64 * 1024
        var chunk = [UInt8](repeating: 0, count: chunkSize)
        var stream = compression_stream()
        var status = compression_stream_init(&stream, COMPRESSION_STREAM_ENCODE, COMPRESSION_ZLIB)
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
            repeat {
                stream.dst_ptr = &chunk
                stream.dst_size = chunkSize
                status = compression_stream_process(&stream, COMPRESSION_STREAM_FINALIZE)
                let produced = chunkSize - stream.dst_size
                if produced > 0 {
                    output.append(chunk, count: produced)
                }
            } while status == COMPRESSION_STATUS_OK
        }
        guard status == COMPRESSION_STATUS_END else {
            throw VPNKeyDecodingError.invalidDecompression
        }
        return output
    }

    static func qrChunks(json: String) -> [String] {
        guard let data = try? compressZlib(Data(json.utf8)) else { return [] }
        let chunkSize = 850
        let count = Int(ceil(Double(data.count) / Double(chunkSize)))
        var result: [String] = []
        var offset = 0
        var chunkId = 0
        while offset < data.count {
            let end = min(offset + chunkSize, data.count)
            let payload = data.subdata(in: offset..<end)
            var packet = Data()
            packet.append(contentsOf: [0x07, 0xC0])
            packet.append(UInt8(count))
            packet.append(UInt8(chunkId))
            var length = UInt32(payload.count).bigEndian
            packet.append(Data(bytes: &length, count: 4))
            packet.append(payload)
            let base64url = packet.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
            result.append(base64url)
            offset = end
            chunkId += 1
        }
        return result
    }
}
