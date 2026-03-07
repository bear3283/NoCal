import SwiftUI

// MARK: - Brand Colors
extension Color {
    // Primary accent: indigo — notes(보라) + calendar(파랑)의 중간점
    static let noCalAccent      = Color.indigo

    // Semantic accent colors (iOS system palette)
    static let noCalEvent       = Color.orange          // 캘린더 이벤트
    static let noCalReminder    = Color.teal            // 미리알림
    static let noCalDone        = Color.green           // 체크박스 완료

    // Surface
    static let noCalSurface     = Color(NoCalTheme.surfaceKey)

    // Derived semantics (computed, adaptive)
    static var noCalTagBg:       Color { Color.noCalAccent.opacity(0.09) }
    static var noCalSelectionBg: Color { Color.noCalAccent.opacity(0.07) }
}

// MARK: - Theme Constants
enum NoCalTheme {

    // MARK: Spacing
    static let sp2:  CGFloat =  2
    static let sp4:  CGFloat =  4
    static let sp6:  CGFloat =  6
    static let sp8:  CGFloat =  8
    static let sp10: CGFloat = 10
    static let sp12: CGFloat = 12
    static let sp16: CGFloat = 16
    static let sp20: CGFloat = 20
    static let sp24: CGFloat = 24

    // Legacy spacing aliases (backwards compatibility)
    static let spacing2:  CGFloat = sp2
    static let spacing4:  CGFloat = sp4
    static let spacing8:  CGFloat = sp8
    static let spacing12: CGFloat = sp12
    static let spacing16: CGFloat = sp16
    static let spacing20: CGFloat = sp20
    static let spacing24: CGFloat = sp24

    // MARK: Corner Radius
    static let radiusXS:    CGFloat =  4
    static let radiusSmall: CGFloat =  6
    static let radiusMed:   CGFloat = 10
    static let radiusLarge: CGFloat = 14
    static let radiusXL:    CGFloat = 20

    // MARK: Icon Sizes
    static let iconSM: CGFloat = 13
    static let iconMD: CGFloat = 16
    static let iconLG: CGFloat = 22

    // MARK: Sidebar Icon Badge (iOS Notes style — colored rounded-rect background)
    static let sidebarIconBadgeSize:   CGFloat = 26
    static let sidebarIconBadgeRadius: CGFloat =  6
    static let sidebarIconBadgeFont:   CGFloat = 13

    // MARK: Note Row
    static let noteRowVerticalPad: CGFloat = 11
    static let noteRowSpacing:     CGFloat =  5

    // MARK: Tag Chip
    static let tagChipHPad: CGFloat = 6
    static let tagChipVPad: CGFloat = 2

    // MARK: Layout Widths
    static let sidebarMinWidth:   CGFloat = 200
    static let sidebarIdealWidth: CGFloat = 230
    static let sidebarMaxWidth:   CGFloat = 280
    static let listMinWidth:      CGFloat = 250
    static let listIdealWidth:    CGFloat = 300
    static let listMaxWidth:      CGFloat = 360
    static let timelineWidth:     CGFloat = 240

    // MARK: Timeline
    static let hourRowHeight: CGFloat = 56

    // MARK: Animations
    static let springFast    = Animation.spring(response: 0.25, dampingFraction: 0.80)
    static let springDefault = Animation.spring(response: 0.35, dampingFraction: 0.75)

    // Internal helper
    static let surfaceKey = "NoCalSurface"
}

// MARK: - View Modifiers
extension View {
    /// 카드 배경: regularMaterial + 둥근 모서리
    func noCalCard() -> some View {
        self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: NoCalTheme.radiusMed))
    }

    /// 태그 Chip 스타일
    func noCalTagChip(color: Color = .noCalAccent) -> some View {
        self
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, NoCalTheme.tagChipHPad)
            .padding(.vertical,   NoCalTheme.tagChipVPad)
            .background(color.opacity(0.09), in: Capsule())
    }

    /// 섹션 수평 패딩
    func noCalSection() -> some View {
        self.padding(.horizontal, NoCalTheme.spacing12)
    }
}

// MARK: - Font Helpers
extension Font {
    /// 앱 로고
    static var noCalLogo: Font { .system(size: 18, weight: .bold, design: .rounded) }
    /// 노트 제목 (에디터)
    static var noteTitle: Font { .system(size: 24, weight: .bold) }
    /// 노트 목록 제목
    static var noteListTitle: Font { .system(size: 15, weight: .semibold) }
    /// 노트 미리보기
    static var notePreview: Font { .system(size: 13, weight: .regular) }
    /// 노트 본문 (에디터)
    static var noteBody: Font { .system(size: 15, weight: .regular) }
    /// 타임라인 시간 표시
    static var timeLabel: Font { .system(size: 12, weight: .regular, design: .monospaced) }
    /// 캘린더 날짜
    static var calendarDay: Font { .system(size: 13, weight: .regular) }
    /// 메타데이터 / 배지
    static var metaLabel: Font { .system(size: 11, weight: .regular) }
}
