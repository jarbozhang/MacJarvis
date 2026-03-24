import Foundation

@Observable @MainActor
final class SystemMonitorService {
    var cpuUsage: Double = 0.0
    /// Memory usage percentage (0–100)
    var memoryUsage: Double = 0.0
    /// Disk usage percentage (0–100) of root volume
    var diskUsage: Double = 0.0
    /// Total physical memory in GB
    var totalMemoryGB: Double = 0.0
    /// Used memory in GB
    var usedMemoryGB: Double = 0.0
    /// Total disk in GB
    var totalDiskGB: Double = 0.0
    /// Used disk in GB
    var usedDiskGB: Double = 0.0

    private var timer: Timer?
    private var previousCPUInfo: host_cpu_load_info?

    func startMonitoring() {
        fetchCPUUsage()
        fetchMemoryUsage()
        fetchDiskUsage()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fetchCPUUsage()
                self?.fetchMemoryUsage()
                self?.fetchDiskUsage()
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

    private func fetchMemoryUsage() {
        let pageSize = Double(vm_kernel_page_size)
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let host = mach_host_self()

        let result = withUnsafeMutablePointer(to: &vmStats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(host, HOST_VM_INFO64, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else { return }

        let totalBytes = Double(ProcessInfo.processInfo.physicalMemory)
        let activeBytes = Double(vmStats.active_count) * pageSize
        let wiredBytes = Double(vmStats.wire_count) * pageSize
        let compressedBytes = Double(vmStats.compressor_page_count) * pageSize
        let usedBytes = activeBytes + wiredBytes + compressedBytes

        totalMemoryGB = totalBytes / 1_073_741_824
        usedMemoryGB = usedBytes / 1_073_741_824
        memoryUsage = totalBytes > 0 ? (usedBytes / totalBytes) * 100.0 : 0
    }

    private func fetchDiskUsage() {
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: "/")
            if let totalSize = attrs[.systemSize] as? Int64,
               let freeSize = attrs[.systemFreeSize] as? Int64 {
                let total = Double(totalSize)
                let used = Double(totalSize - freeSize)
                totalDiskGB = total / 1_073_741_824
                usedDiskGB = used / 1_073_741_824
                diskUsage = total > 0 ? (used / total) * 100.0 : 0
            }
        } catch {}
    }
}
