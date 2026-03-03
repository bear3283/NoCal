//  NoCalApp.swift
//  NoCal — Note + Calendar
//  Phase 4: App Intents, Commands, CloudKit 준비.
//
//  ⚠️ Xcode 설정 필요:
//  Target › Info 탭:
//    NSCalendarsFullAccessUsageDescription   "nocal이 캘린더를 읽고 일정을 생성합니다"
//    NSRemindersFullAccessUsageDescription   "nocal이 미리알림을 읽고 완료 처리합니다"
//  macOS Sandbox › Entitlements:
//    com.apple.security.personal-information.calendars
//    com.apple.security.personal-information.reminders
//  Phase 4 CloudKit:
//    Target › Signing & Capabilities › + iCloud › CloudKit
//    Container: iCloud.com.yourname.nocal

import SwiftUI
import SwiftData
import AppIntents

@main
struct NoCalApp: App {

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Note.self,
            Folder.self,
            TimedTask.self,
            NoteTemplate.self,   // Phase 4
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // 스키마 변경으로 인한 기존 스토어 불일치 → 스토어 삭제 후 재생성
            // ⚠️ 개발 전용: 프로덕션에서는 SchemaMigrationPlan으로 마이그레이션 구현 필요
            print("⚠️ SwiftData 스키마 불일치, 스토어 재초기화: \(error)")
            let storeURL = config.url
            let walURL   = storeURL.appendingPathExtension("wal")
            let shmURL   = storeURL.appendingPathExtension("shm")
            [storeURL, walURL, shmURL].forEach { try? FileManager.default.removeItem(at: $0) }
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("ModelContainer 생성 최종 실패: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .defaultSize(width: 1280, height: 800)
        .windowResizability(.contentMinSize)
        .commands { NoCalCommands() }
        #endif

        #if os(macOS)
        Settings {
            NoCalSettingsView()
        }
        #endif
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - macOS Menu Commands
// ─────────────────────────────────────────────────────────────────────────────

#if os(macOS)
struct NoCalCommands: Commands {

    var body: some Commands {

        // ── File 메뉴 ────────────────────────────────────────────────────────
        CommandGroup(after: .newItem) {
            Button("새 노트") {
                NotificationCenter.default.post(name: .noCalNewNote, object: nil)
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("오늘 일일 노트") {
                NotificationCenter.default.post(name: .noCalOpenToday, object: nil)
            }
            .keyboardShortcut("d", modifiers: .command)

            Divider()

            Button("새 폴더") {
                NotificationCenter.default.post(name: .noCalNewFolder, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }

        // ── View 메뉴 ────────────────────────────────────────────────────────
        CommandGroup(after: .sidebar) {
            Button("타임라인 보기/숨기기") {
                NotificationCenter.default.post(name: .noCalToggleTimeline, object: nil)
            }
            .keyboardShortcut("t", modifiers: [.command, .option])

            Divider()

            Button("오늘로 이동") {
                NotificationCenter.default.post(name: .noCalGoToToday, object: nil)
            }
            .keyboardShortcut(".", modifiers: .command)

            Button("다음 날") {
                NotificationCenter.default.post(name: .noCalNextDay, object: nil)
            }
            .keyboardShortcut(.rightArrow, modifiers: .command)

            Button("이전 날") {
                NotificationCenter.default.post(name: .noCalPreviousDay, object: nil)
            }
            .keyboardShortcut(.leftArrow, modifiers: .command)
        }

        // ── Format 메뉴 ──────────────────────────────────────────────────────
        CommandMenu("서식") {
            Button("굵게") {
                NotificationCenter.default.post(name: .noCalFormat, object: MarkdownAction.bold)
            }
            .keyboardShortcut("b", modifiers: .command)

            Button("기울임") {
                NotificationCenter.default.post(name: .noCalFormat, object: MarkdownAction.italic)
            }
            .keyboardShortcut("i", modifiers: .command)

            Button("코드") {
                NotificationCenter.default.post(name: .noCalFormat, object: MarkdownAction.inlineCode)
            }
            .keyboardShortcut("k", modifiers: .command)

            Divider()

            Button("제목 1") {
                NotificationCenter.default.post(name: .noCalFormat, object: MarkdownAction.h1)
            }
            .keyboardShortcut("1", modifiers: [.command, .shift])

            Button("제목 2") {
                NotificationCenter.default.post(name: .noCalFormat, object: MarkdownAction.h2)
            }
            .keyboardShortcut("2", modifiers: [.command, .shift])

            Button("제목 3") {
                NotificationCenter.default.post(name: .noCalFormat, object: MarkdownAction.h3)
            }
            .keyboardShortcut("3", modifiers: [.command, .shift])

            Divider()

            Button("체크박스") {
                NotificationCenter.default.post(name: .noCalFormat, object: MarkdownAction.checkbox)
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])

            Button("글머리 기호") {
                NotificationCenter.default.post(name: .noCalFormat, object: MarkdownAction.bullet)
            }
            .keyboardShortcut("8", modifiers: [.command, .shift])

            Button("인용구") {
                NotificationCenter.default.post(name: .noCalFormat, object: MarkdownAction.quote)
            }
            .keyboardShortcut("'", modifiers: .command)

            Button("구분선") {
                NotificationCenter.default.post(name: .noCalFormat, object: MarkdownAction.divider)
            }
            .keyboardShortcut("-", modifiers: [.command, .shift])
        }

        // ── Note 메뉴 ────────────────────────────────────────────────────────
        CommandMenu("노트") {
            Button("고정/고정 해제") {
                NotificationCenter.default.post(name: .noCalTogglePin, object: nil)
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])

            Button("노트 삭제") {
                NotificationCenter.default.post(name: .noCalDeleteNote, object: nil)
            }
            .keyboardShortcut(.delete, modifiers: .command)

            Divider()

            Button("템플릿으로 만들기") {
                NotificationCenter.default.post(name: .noCalShowTemplates, object: nil)
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])
        }
    }
}
#endif

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Notification Names
// ─────────────────────────────────────────────────────────────────────────────

extension Notification.Name {
    static let noCalNewNote        = Notification.Name("noCalNewNote")
    static let noCalOpenToday      = Notification.Name("noCalOpenToday")
    static let noCalNewFolder      = Notification.Name("noCalNewFolder")
    static let noCalToggleTimeline = Notification.Name("noCalToggleTimeline")
    static let noCalGoToToday      = Notification.Name("noCalGoToToday")
    static let noCalNextDay        = Notification.Name("noCalNextDay")
    static let noCalPreviousDay    = Notification.Name("noCalPreviousDay")
    static let noCalFormat         = Notification.Name("noCalFormat")
    static let noCalTogglePin      = Notification.Name("noCalTogglePin")
    static let noCalDeleteNote     = Notification.Name("noCalDeleteNote")
    static let noCalShowTemplates  = Notification.Name("noCalShowTemplates")
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Settings View (Phase 4)
// ─────────────────────────────────────────────────────────────────────────────

struct NoCalSettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("일반", systemImage: "gear") }

            CloudSyncSettingsTab()
                .tabItem { Label("동기화", systemImage: "icloud") }

            CalendarSettingsTab()
                .tabItem { Label("캘린더", systemImage: "calendar") }

            AboutSettingsTab()
                .tabItem { Label("정보", systemImage: "info.circle") }
        }
        .frame(minWidth: 480, minHeight: 320)
    }
}

private struct GeneralSettingsTab: View {
    @AppStorage("editorFontSize") private var editorFontSize: Double = 15
    @AppStorage("autoSaveDelay")  private var autoSaveDelay: Double = 0.8
    @AppStorage("showWordCount")  private var showWordCount: Bool = true

    var body: some View {
        Form {
            Section("편집기") {
                HStack {
                    Text("글꼴 크기")
                    Spacer()
                    Stepper("\(Int(editorFontSize))pt",
                            value: $editorFontSize, in: 12...24, step: 1)
                }
                HStack {
                    Text("자동 저장")
                    Spacer()
                    Stepper(String(format: "%.1f초", autoSaveDelay),
                            value: $autoSaveDelay, in: 0.3...3.0, step: 0.1)
                }
                Toggle("단어 수 표시", isOn: $showWordCount)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(minHeight: 200)
    }
}

private struct CloudSyncSettingsTab: View {
    private var sync = SyncService.shared

    var body: some View {
        Form {
            Section("iCloud 동기화") {
                SyncStatusView()

                Button {
                    Task { await sync.triggerSync() }
                } label: {
                    Label("지금 동기화", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(sync.syncStatus == .syncing || !sync.isOnline)
            }

            #if DEBUG
            Section("설정 안내") {
                CloudKitSetupGuideView()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            #endif
        }
        .formStyle(.grouped)
        .padding()
        .frame(minHeight: 200)
    }
}

private struct CalendarSettingsTab: View {
    var body: some View {
        Form {
            Section("EventKit 권한") {
                LabeledContent("캘린더 권한") {
                    let s = EventKitService.shared
                    HStack {
                        Text(s.hasCalendarAccess ? "허용됨" : "미허용")
                            .foregroundStyle(s.hasCalendarAccess ? .green : .secondary)
                        if !s.hasCalendarAccess {
                            Button("허용") {
                                Task { await s.requestCalendarAccess() }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                }
                LabeledContent("미리알림 권한") {
                    let s = EventKitService.shared
                    HStack {
                        Text(s.hasRemindersAccess ? "허용됨" : "미허용")
                            .foregroundStyle(s.hasRemindersAccess ? .green : .secondary)
                        if !s.hasRemindersAccess {
                            Button("허용") {
                                Task { await s.requestRemindersAccess() }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(minHeight: 200)
    }
}

private struct AboutSettingsTab: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "note.text.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(Color.noCalAccent)

            Text("nocal")
                .font(.largeTitle.weight(.bold))

            Text("Note + Calendar")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("버전 1.0.0 (Phase 4)")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Divider()

            Text("오늘의 생각과 시간을 하나의 흐름으로")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(minHeight: 200)
    }
}
