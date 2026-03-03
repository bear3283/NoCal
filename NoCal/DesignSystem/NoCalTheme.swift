import SwiftUI

// MARK: - Brand Colors
extension Color {
    /// nocal 시그니처 인디고 (Note + Calendar를 잇는 색)
    static let noCalAccent  = Color.indigo
    static let noCalSurface = Color(NoCalTheme.surfaceKey)
}

// MARK: - Theme Constants
enum NoCalTheme {
    // Spacing
    static let spacing2: CGFloat   = 2
    static let spacing4: CGFloat   = 4
    static let spacing8: CGFloat   = 8
    static let spacing12: CGFloat  = 12
    static let spacing16: CGFloat  = 16
    static let spacing20: CGFloat  = 20
    static let spacing24: CGFloat  = 24

    // Corner Radius
    static let radiusSmall: CGFloat  = 6
    static let radiusMed: CGFloat    = 10
    static let radiusLarge: CGFloat  = 14

    // Icon sizes
    static let iconSM: CGFloat = 14
    static let iconMD: CGFloat = 18
    static let iconLG: CGFloat = 24

    // Sidebar
    static let sidebarMinWidth: CGFloat  = 200
    static let sidebarIdealWidth: CGFloat = 240
    static let sidebarMaxWidth: CGFloat  = 300

    // Note List
    static let listMinWidth: CGFloat  = 240
    static let listIdealWidth: CGFloat = 280
    static let listMaxWidth: CGFloat  = 340

    // Timeline
    static let timelineWidth: CGFloat = 240
    static let hourRowHeight: CGFloat = 56

    // Internal helper
    static let surfaceKey = "NoCalSurface"
}

// MARK: - View Modifiers
extension View {
    func noCalCard() -> some View {
        self
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: NoCalTheme.radiusMed))
    }

    func noCalSection() -> some View {
        self.padding(.horizontal, NoCalTheme.spacing12)
    }
}

// MARK: - Font Helpers
extension Font {
    /// 앱 로고 타이포그래피
    static var noCalLogo: Font { .system(size: 18, weight: .bold, design: .rounded) }
    /// 노트 제목
    static var noteTitle: Font { .system(size: 24, weight: .bold) }
    /// 노트 본문
    static var noteBody: Font { .system(size: 15, weight: .regular) }
    /// 타임라인 시간 표시 (SF Mono)
    static var timeLabel: Font { .system(size: 12, weight: .regular, design: .monospaced) }
    /// 캘린더 날짜
    static var calendarDay: Font { .system(size: 13, weight: .regular) }
}
