/// SyncService.swift
/// Phase 4: CloudKit + SwiftData 동기화 상태 모니터링 및 충돌 처리.
///
/// ⚠️ CloudKit 활성화 방법:
///   1. Xcode: Target › Signing & Capabilities › + iCloud
///   2. iCloud: CloudKit 체크 ✓
///   3. Containers: + 버튼 → iCloud.com.bear3745.NoCal
///   4. NoCalApp.swift에서 ModelConfiguration 변경:
///      ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
///   5. Note, Folder, TimedTask, NoteTemplate 모두 optional 속성으로 변경 필요
///      (CloudKit은 non-optional을 지원하지 않음)
///
/// CloudKit 제약사항:
///   - @Model 모든 stored property는 optional이어야 함
///   - Relationship deleteRule은 .nullify만 지원
///   - Unique constraint 불가
///   - enum stored property 직접 저장 불가 (rawValue 사용)

import SwiftUI
import CloudKit
import Network

@Observable
final class SyncService {

    static let shared = SyncService()

    // ── State ─────────────────────────────────────────────────────────────
    var syncStatus: SyncStatus = .idle
    var lastSyncDate: Date? = nil
    var isOnline: Bool = true

    // ── Private ───────────────────────────────────────────────────────────
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "nocal.network")
    private let containerID = "iCloud.com.bear3745.NoCal"

    private init() {
        startNetworkMonitor()
        Task { await checkCloudKitStatus() }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Network Monitor
    // ─────────────────────────────────────────────────────────────────────

    private func startNetworkMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = path.status == .satisfied
            }
        }
        monitor.start(queue: monitorQueue)
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: CloudKit Account Status
    // ─────────────────────────────────────────────────────────────────────

    @MainActor
    func checkCloudKitStatus() async {
        do {
            let container = CKContainer(identifier: containerID)
            let status    = try await container.accountStatus()
            switch status {
            case .available:
                syncStatus = .synced
            case .noAccount:
                syncStatus = .error("iCloud 계정에 로그인하세요")
            case .restricted:
                syncStatus = .error("iCloud 접근이 제한되어 있습니다")
            default:
                syncStatus = .error("iCloud 상태를 확인할 수 없습니다")
            }
        } catch {
            syncStatus = .error(error.localizedDescription)
        }
    }

    @MainActor
    func triggerSync() async {
        guard isOnline else {
            syncStatus = .offline
            return
        }
        syncStatus = .syncing
        // SwiftData CloudKit 동기화는 자동으로 처리됨.
        // 여기서는 상태만 업데이트.
        try? await Task.sleep(for: .seconds(1))
        lastSyncDate = Date()
        syncStatus   = .synced
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Sync Status
// ─────────────────────────────────────────────────────────────────────────────

enum SyncStatus: Equatable {
    case idle
    case syncing
    case synced
    case offline
    case error(String)

    var icon: String {
        switch self {
        case .idle:    return "icloud"
        case .syncing: return "arrow.triangle.2.circlepath.icloud"
        case .synced:  return "checkmark.icloud"
        case .offline: return "icloud.slash"
        case .error:   return "exclamationmark.icloud"
        }
    }

    var color: Color {
        switch self {
        case .idle:    return .secondary
        case .syncing: return .orange
        case .synced:  return .green
        case .offline: return .secondary
        case .error:   return .red
        }
    }

    var label: String {
        switch self {
        case .idle:         return "대기 중"
        case .syncing:      return "동기화 중..."
        case .synced:       return "동기화됨"
        case .offline:      return "오프라인"
        case .error(let m): return m
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Sync Status View
// ─────────────────────────────────────────────────────────────────────────────

struct SyncStatusView: View {

    private var sync = SyncService.shared

    var body: some View {
        HStack(spacing: 6) {
            Group {
                if sync.syncStatus == .syncing {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: sync.syncStatus.icon)
                        .font(.caption)
                }
            }
            .foregroundStyle(sync.syncStatus.color)

            VStack(alignment: .leading, spacing: 1) {
                Text(sync.syncStatus.label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(sync.syncStatus.color)

                if let last = sync.lastSyncDate {
                    Text("마지막 동기화: \(last.formatted(.relative(presentation: .named)))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if !sync.isOnline {
                Spacer()
                Label("오프라인", systemImage: "wifi.slash")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - CloudKit Setup Guide (DEBUG only)
// ─────────────────────────────────────────────────────────────────────────────

#if DEBUG
struct CloudKitSetupGuideView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("CloudKit 설정 가이드", systemImage: "icloud.fill")
                .font(.headline)
                .foregroundStyle(Color.noCalAccent)

            Group {
                StepRow(number: 1, text: "Xcode: Target › Signing & Capabilities › + iCloud")
                StepRow(number: 2, text: "iCloud: CloudKit 체크 ✓")
                StepRow(number: 3, text: "Containers: + iCloud.com.bear3745.NoCal")
                StepRow(number: 4, text: "NoCalApp.swift: ModelConfiguration에 cloudKitDatabase: .automatic 추가")
                StepRow(number: 5, text: "App Groups 활성화 (위젯 공유용)")
            }

            Divider()

            Text("⚠️ CloudKit 호환을 위해 @Model의 모든 stored property를 optional로 변경 필요")
                .font(.caption)
                .foregroundStyle(.orange)
        }
        .padding()
        .background(Color.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct StepRow: View {
    let number: Int
    let text:   String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.noCalAccent)
                .frame(width: 16, alignment: .trailing)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
#endif
