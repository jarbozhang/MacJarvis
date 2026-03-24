import Foundation
import IOKit

@Observable @MainActor
final class SystemMonitorService {
    var cpuUsage: Double = 0.0
    var cpuTemperature: Double? = nil

    private var timer: Timer?
    private var previousCPUInfo: host_cpu_load_info?

    func startMonitoring() {
        fetchCPUUsage()
        fetchCPUTemperature()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fetchCPUUsage()
                self?.fetchCPUTemperature()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func fetchCPUUsage() {
        var cpuLoad = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
        let host = mach_host_self()

        let result = withUnsafeMutablePointer(to: &cpuLoad) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics(host, HOST_CPU_LOAD_INFO, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else { return }

        if let prev = previousCPUInfo {
            let userDiff = Double(cpuLoad.cpu_ticks.0 - prev.cpu_ticks.0)
            let sysDiff = Double(cpuLoad.cpu_ticks.1 - prev.cpu_ticks.1)
            let idleDiff = Double(cpuLoad.cpu_ticks.2 - prev.cpu_ticks.2)
            let niceDiff = Double(cpuLoad.cpu_ticks.3 - prev.cpu_ticks.3)
            let totalDiff = userDiff + sysDiff + idleDiff + niceDiff
            if totalDiff > 0 {
                cpuUsage = ((userDiff + sysDiff + niceDiff) / totalDiff) * 100.0
            }
        }
        previousCPUInfo = cpuLoad
    }

    private func fetchCPUTemperature() {
        Task.detached { [weak self] in
            let temp = Self.readSMCTemperature()
            await MainActor.run { [weak self] in
                self?.cpuTemperature = temp
            }
        }
    }

    private nonisolated static func readSMCTemperature() -> Double? {
        let serviceName = "AppleSMC"
        var conn: io_connect_t = 0

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(serviceName))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        let openResult = IOServiceOpen(service, mach_task_self_, 0, &conn)
        guard openResult == kIOReturnSuccess else { return nil }
        defer { IOServiceClose(conn) }

        // Step 1: getKeyInfo (data8 = 9) to learn dataSize and dataType
        var infoInput = SMCKeyData()
        infoInput.key = fourCharCode("TC0P")
        infoInput.data8 = 9  // kSMCGetKeyInfo

        var infoOutput = SMCKeyData()
        var outputSize = MemoryLayout<SMCKeyData>.stride

        var result = IOConnectCallStructMethod(
            conn, 2,
            &infoInput, MemoryLayout<SMCKeyData>.stride,
            &infoOutput, &outputSize
        )
        guard result == kIOReturnSuccess else { return nil }

        // Step 2: readKey (data8 = 5) with keyInfo from step 1
        var readInput = SMCKeyData()
        readInput.key = fourCharCode("TC0P")
        readInput.keyInfo.dataSize = infoOutput.keyInfo.dataSize
        readInput.keyInfo.dataType = infoOutput.keyInfo.dataType
        readInput.keyInfo.dataAttributes = infoOutput.keyInfo.dataAttributes
        readInput.data8 = 5  // kSMCReadKey

        var readOutput = SMCKeyData()
        outputSize = MemoryLayout<SMCKeyData>.stride

        result = IOConnectCallStructMethod(
            conn, 2,
            &readInput, MemoryLayout<SMCKeyData>.stride,
            &readOutput, &outputSize
        )
        guard result == kIOReturnSuccess else { return nil }

        // Parse temperature based on data type
        let dataType = infoOutput.keyInfo.dataType
        let sp78 = fourCharCode("sp78")  // signed 7.8 fixed point
        let flt  = fourCharCode("flt ")  // float32

        var temperature: Double
        if dataType == sp78 {
            // sp78: signed 7-bit integer + 8-bit fraction
            let intPart = Double(Int8(bitPattern: readOutput.bytes.0))
            let fracPart = Double(readOutput.bytes.1) / 256.0
            temperature = intPart + fracPart
        } else if dataType == flt {
            // flt: 32-bit float (big-endian)
            let b0 = readOutput.bytes.0, b1 = readOutput.bytes.1
            let b2 = readOutput.bytes.2, b3 = readOutput.bytes.3
            let rawBits = UInt32(b0) << 24 | UInt32(b1) << 16 | UInt32(b2) << 8 | UInt32(b3)
            temperature = Double(Float(bitPattern: rawBits))
        } else {
            // Fallback: treat as unsigned 8.8 fixed point
            temperature = Double(readOutput.bytes.0) + Double(readOutput.bytes.1) / 256.0
        }

        return temperature > 0 && temperature < 150 ? temperature : nil
    }

    private nonisolated static func fourCharCode(_ str: String) -> UInt32 {
        var result: UInt32 = 0
        for char in str.utf8.prefix(4) {
            result = (result << 8) | UInt32(char)
        }
        return result
    }
}

private struct SMCKeyData {
    var key: UInt32 = 0
    var vers = SMCVersion()
    var pLimitData = SMCPLimitData()
    var keyInfo = SMCKeyInfoData()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) =
        (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
}

private struct SMCVersion {
    var major: CUnsignedChar = 0
    var minor: CUnsignedChar = 0
    var build: CUnsignedChar = 0
    var reserved: CUnsignedChar = 0
    var release: CUnsignedShort = 0
}

private struct SMCPLimitData {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

private struct SMCKeyInfoData {
    var dataSize: IOByteCount = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}
