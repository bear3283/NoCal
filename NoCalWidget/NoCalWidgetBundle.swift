/// NoCalWidgetBundle.swift
/// Phase 4: Widget Extension 번들 — 3종 커스텀 위젯 등록.

import WidgetKit
import SwiftUI

@main
struct NoCalWidgetBundle: WidgetBundle {
    var body: some Widget {
        NoCalTimelineWidget()   // 오늘 캘린더 일정
        NoCalTodoWidget()       // 오늘 체크리스트
        NoCalNotesWidget()      // 최근 노트 목록
    }
}
