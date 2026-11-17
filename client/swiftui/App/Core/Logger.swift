import Foundation

final class Logger {
    static let shared = Logger()

    let appLogURL: URL
    let tunnelLogURL: URL

    private let queue = DispatchQueue(label: "org.amnezia.logger")

    private init() {
        let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: BuildConfig.appGroupIdentifier)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let logsDirectory = container.appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        appLogURL = logsDirectory.appendingPathComponent("app.log")
        tunnelLogURL = logsDirectory.appendingPathComponent("tunnel.log")
    }

    func log(_ message: String, stream: Stream = .app) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        queue.async {
            let url = stream == .app ? self.appLogURL : self.tunnelLogURL
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(Data(line.utf8))
                try? handle.close()
            } else {
                try? Data(line.utf8).write(to: url)
            }
        }
    }

    func contents(stream: Stream) -> String {
        let url = stream == .app ? appLogURL : tunnelLogURL
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    func sizeDescription(stream: Stream) -> String {
        let url = stream == .app ? appLogURL : tunnelLogURL
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    func clearAll() {
        try? FileManager.default.removeItem(at: appLogURL)
        try? FileManager.default.removeItem(at: tunnelLogURL)
    }

    func zipData() -> Data? {
        let appContents = contents(stream: .app)
        let tunnelContents = contents(stream: .tunnel)
        return ZipWriter.data(for: [("app.log", appContents), ("tunnel.log", tunnelContents)])
    }

    enum Stream {
        case app
        case tunnel
    }
}

enum ZipWriter {
    static func data(for files: [(name: String, content: String)]) -> Data? {
        var output = Data()
        var centralDirectory = Data()
        for (name, content) in files {
            guard let nameData = name.data(using: .utf8),
                  let contentData = content.data(using: .utf8) else { continue }
            let crc = contentData.crc32
            let offset = UInt32(output.count)
            var header = Data()
            header.append(contentsOf: [0x50, 0x4B, 0x03, 0x04])
            header.append(contentsOf: withUnsafeBytes(of: UInt16(20).littleEndian, Array.init))
            header.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian, Array.init))
            header.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian, Array.init))
            header.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian, Array.init))
            header.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian, Array.init))
            header.append(contentsOf: withUnsafeBytes(of: crc.littleEndian, Array.init))
            header.append(contentsOf: withUnsafeBytes(of: UInt32(contentData.count).littleEndian, Array.init))
            header.append(contentsOf: withUnsafeBytes(of: UInt32(contentData.count).littleEndian, Array.init))
            header.append(contentsOf: withUnsafeBytes(of: UInt16(nameData.count).littleEndian, Array.init))
            header.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian, Array.init))
            header.append(nameData)
            output.append(header)
            output.append(contentData)
            var central = Data()
            central.append(contentsOf: [0x50, 0x4B, 0x01, 0x02])
            central.append(contentsOf: withUnsafeBytes(of: UInt16(20).littleEndian, Array.init))
            central.append(contentsOf: withUnsafeBytes(of: UInt16(20).littleEndian, Array.init))
            central.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian, Array.init))
            central.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian, Array.init))
            central.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian, Array.init))
            central.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian, Array.init))
            central.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian, Array.init))
            central.append(contentsOf: withUnsafeBytes(of: crc.littleEndian, Array.init))
            central.append(contentsOf: withUnsafeBytes(of: UInt32(contentData.count).littleEndian, Array.init))
            central.append(contentsOf: withUnsafeBytes(of: UInt32(contentData.count).littleEndian, Array.init))
            central.append(contentsOf: withUnsafeBytes(of: UInt16(nameData.count).littleEndian, Array.init))
            central.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian, Array.init))
            central.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian, Array.init))
            central.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian, Array.init))
            central.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian, Array.init))
            central.append(contentsOf: withUnsafeBytes(of: UInt32(0).littleEndian, Array.init))
            central.append(contentsOf: withUnsafeBytes(of: offset.littleEndian, Array.init))
            central.append(nameData)
            centralDirectory.append(central)
        }
        let centralOffset = UInt32(output.count)
        output.append(centralDirectory)
        var end = Data()
        end.append(contentsOf: [0x50, 0x4B, 0x05, 0x06])
        end.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian, Array.init))
        end.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian, Array.init))
        end.append(contentsOf: withUnsafeBytes(of: UInt16(files.count).littleEndian, Array.init))
        end.append(contentsOf: withUnsafeBytes(of: UInt16(files.count).littleEndian, Array.init))
        end.append(contentsOf: withUnsafeBytes(of: UInt32(centralDirectory.count).littleEndian, Array.init))
        end.append(contentsOf: withUnsafeBytes(of: centralOffset.littleEndian, Array.init))
        end.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian, Array.init))
        output.append(end)
        return output
    }
}

extension Data {
    var crc32: UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in self {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc >> 1) ^ (crc & 1 == 1 ? 0xEDB88320 : 0)
            }
        }
        return crc ^ 0xFFFFFFFF
    }
}
