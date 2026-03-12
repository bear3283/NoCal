/// DashboardView.swift
/// 3-패널 대시보드: 좌측(캘린더 + 미리알림) | 우측(노트목록 + 에디터)
/// - 패널 크기: 드래그로 자유롭게 조절 (AppStorage에 저장)
/// - 레이아웃 프리셋: 집중 / 기본 / 플래너 (툴바 세그먼트 또는 설정에서 변경)

import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Panel Preset
// ─────────────────────────────────────────────────────────────────────────────

enum PanelPreset: String, CaseIterable {
    case focus    = "focus"     // 노트 전용 (좌측 패널 숨김)
    case `default` = "default" // 기본 균형 레이아웃
    case planner  = "planner"  // 캘린더 크게

    var label: String {
        switch self {
        case .focus:    return "집중"
        case .default:  return "기본"
        case .planner:  return "플래너"
        }
    }

    var icon: String {
        switch self {
        case .focus:    return "rectangle"
        case .default:  return "rectangle.split.2x1"
        case .planner:  return "calendar"
        }
    }

    var leftWidth:    Double { self == .planner ? 340 : 280 }
    var calFraction:  Double { self == .planner ? 0.65 : 0.55 }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - DashboardView
// ─────────────────────────────────────────────────────────────────────────────

struct DashboardView: View {

    @Environment(AppViewModel.self) private var appViewModel

    @AppStorage("panelPreset")       private var presetRaw:       String = PanelPreset.default.rawValue
    @AppStorage("leftPanelWidth")    private var leftWidth:       Double = 280
    @AppStorage("calRemFraction")    private var calFrac:         Double = 0.55
    @AppStorage("noteListVisible")   private var noteListVisible: Bool   = true

    private var preset: PanelPreset { PanelPreset(rawValue: presetRaw) ?? .default }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {

                // ── 좌측 패널: 캘린더 + 미리알림 ────────────────────────
                if preset != .focus {
                    let clamped = min(max(leftWidth, 200), geo.size.width * 0.45)

                    GeometryReader { leftGeo in
                        VStack(spacing: 0) {
                            CalendarPanelView()
                                .frame(
                                    height: leftGeo.size.height > 0
                                        ? max(150, leftGeo.size.height * calFrac - 4)
                                        : 220
                                )

                            VerticalDragHandle { delta in
                                guard leftGeo.size.height > 0 else { return }
                                calFrac = max(0.25, min(0.80,
                                    calFrac + delta / leftGeo.size.height))
                            }

                            RemindersPanelView()
                                .frame(maxHeight: .infinity)
                        }
                    }
                    .frame(width: clamped)
                    .background(Color(nsColor: .controlBackgroundColor))

                    HorizontalDragHandle { delta in
                        leftWidth = max(200, min(geo.size.width * 0.45, leftWidth + delta))
                    }
                }

                // ── 우측: 노트 목록 + 에디터 ────────────────────────────
                HStack(spacing: 0) {
                    if noteListVisible {
                        NoteListView()
                            .frame(width: 220)
                        Divider()
                    }

                    NoteEditorView()
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .toolbar { layoutToolbar }
    }

    // ── 레이아웃 프리셋 툴바 ────────────────────────────────────────────────
    @ToolbarContentBuilder
    private var layoutToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Picker("레이아웃", selection: $presetRaw) {
                ForEach(PanelPreset.allCases, id: \.rawValue) { p in
                    Label(p.label, systemImage: p.icon).tag(p.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 150)
            .help("레이아웃 선택")
            .onChange(of: presetRaw) { _, raw in
                guard let p = PanelPreset(rawValue: raw) else { return }
                withAnimation(.easeInOut(duration: 0.22)) {
                    leftWidth = p.leftWidth
                    calFrac   = p.calFraction
                }
            }
        }

        ToolbarItem(placement: .navigation) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    noteListVisible.toggle()
                }
            } label: {
                Image(systemName: noteListVisible ? "sidebar.left" : "sidebar.left")
                    .symbolVariant(noteListVisible ? .fill : .none)
            }
            .help(noteListVisible ? "노트 목록 숨기기" : "노트 목록 보기")
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Drag Handles
// ─────────────────────────────────────────────────────────────────────────────

/// 좌우 패널 너비 조절 (수직선 드래그)
private struct HorizontalDragHandle: View {
    let onDrag: (Double) -> Void

    @State private var lastX:       Double = 0
    @State private var isHovering:  Bool   = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(isHovering ? Color.noCalAccent.opacity(0.3) : Color.clear)
                .frame(width: 5)
            Divider()
        }
        .frame(width: 5)
        .contentShape(Rectangle())
        .onHover { h in
            isHovering = h
            #if os(macOS)
            if h { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
            #endif
        }
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { v in
                    let delta = v.translation.width - lastX
                    lastX = v.translation.width
                    onDrag(delta)
                }
                .onEnded { _ in lastX = 0 }
        )
    }
}

/// 캘린더/미리알림 상하 비율 조절 (수평선 드래그)
private struct VerticalDragHandle: View {
    let onDrag: (Double) -> Void

    @State private var lastY:       Double = 0
    @State private var isHovering:  Bool   = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(isHovering ? Color.noCalAccent.opacity(0.3) : Color.secondary.opacity(0.1))
            Divider()
        }
        .frame(height: 5)
        .onHover { h in
            isHovering = h
            #if os(macOS)
            if h { NSCursor.resizeUpDown.push() } else { NSCursor.pop() }
            #endif
        }
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { v in
                    let delta = v.translation.height - lastY
                    lastY = v.translation.height
                    onDrag(delta)
                }
                .onEnded { _ in lastY = 0 }
        )
    }
}
