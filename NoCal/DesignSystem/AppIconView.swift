/// AppIconView.swift
/// NoCal 앱 아이콘 — 글래스모피즘 + 인디고 단색 디자인
///
/// 디자인 컨셉:
///   - 배경: 딥 인디고 그라디언트 (진한 → 네이비)
///   - 주변 광원: 우상단 화이트 방사형 글로우 (빛의 방향성)
///   - 글래스 카드: 흰색 13% + 그라디언트 테두리 (-7° 틸트)
///   - 심볼 (화이트):
///       캘린더 도트 그리드 (주간 뷰 스타일, 오늘=강조)
///       수평 구분선
///       노트 텍스트 라인 3개 (미리보기)
///   - 미리알림 표시: 마지막 캘린더 도트에 링 (알림 배지)
///
/// Usage:
///   AppIconView()                    → 512pt 풀 아이콘 (내보내기용)
///   AppIconView(size: 64)            → 소형 (About, Onboarding)
///   AppIconView(size: 32)            → 미니 (사이드바 로고 등)

import SwiftUI

struct AppIconView: View {

    /// 렌더링 크기 (기본 512pt)
    var size: CGFloat = 512

    // ── Derived metrics ──────────────────────────────────────────────────
    private var iconRadius:   CGFloat { size * 0.2237 } // iOS 표준 코너 비율
    private var cardRadius:   CGFloat { size * 0.110  }
    private var cardWidth:    CGFloat { size * 0.630  }
    private var cardHeight:   CGFloat { size * 0.700  }
    private var cardTilt:     Double  { -7.0           }

    private var symbolW:      CGFloat { size * 0.470  }
    private var dotSize:      CGFloat { size * 0.048  }
    private var lineH:        CGFloat { size * 0.026  }
    private var spacing:      CGFloat { size * 0.038  }

    // ── Body ─────────────────────────────────────────────────────────────
    var body: some View {
        ZStack {
            backgroundLayer
            glowLayer
            glassCard
                .frame(width: cardWidth, height: cardHeight)
                .rotationEffect(.degrees(cardTilt))
            symbolLayer
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: iconRadius, style: .continuous))
    }

    // ── Background: deep indigo gradient ─────────────────────────────────
    private var backgroundLayer: some View {
        LinearGradient(
            stops: [
                .init(color: Color(hue: 0.662, saturation: 0.80, brightness: 0.54), location: 0.0),
                .init(color: Color(hue: 0.675, saturation: 0.90, brightness: 0.38), location: 0.55),
                .init(color: Color(hue: 0.698, saturation: 0.96, brightness: 0.22), location: 1.0),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // ── Ambient glow: white light source at top-right ────────────────────
    private var glowLayer: some View {
        ZStack {
            // Primary glow (top-right)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.24), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.40
                    )
                )
                .frame(width: size * 0.80, height: size * 0.80)
                .offset(x: size * 0.22, y: -size * 0.26)

            // Secondary ambient (bottom-left, cooler)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.06), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.30
                    )
                )
                .frame(width: size * 0.60, height: size * 0.60)
                .offset(x: -size * 0.28, y: size * 0.30)
        }
    }

    // ── Glassmorphism card ────────────────────────────────────────────────
    private var glassCard: some View {
        RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
            // Frosted fill
            .fill(Color.white.opacity(0.12))
            // Inner highlight layer (glass surface sheen)
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                    )
                    .padding(max(1, size * 0.005))
            }
            // Border: bright top-left edge → dim bottom-right (glass edge catching light)
            .overlay(
                RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.50),
                                Color.white.opacity(0.20),
                                Color.white.opacity(0.05),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: max(1, size * 0.005)
                    )
            )
    }

    // ── Symbol: calendar + divider + note lines ──────────────────────────
    private var symbolLayer: some View {
        VStack(alignment: .leading, spacing: spacing) {
            calendarSection
            dividerLine
            noteLinesSection
        }
        .frame(width: symbolW)
    }

    // MARK: Calendar — header bar + week dot row
    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: size * 0.024) {

            // Month header bar
            Capsule()
                .fill(Color.white.opacity(0.90))
                .frame(width: symbolW * 0.55, height: lineH * 0.85)

            // Week strip: 7 dots (Sun–Sat)
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { col in
                    let isToday    = (col == 3)          // Wednesday = "today"
                    let isReminder = (col == 5)          // Friday = reminder set

                    ZStack {
                        // Reminder ring (bell indicator)
                        if isReminder {
                            Circle()
                                .strokeBorder(Color.white.opacity(0.70), lineWidth: max(1, size * 0.007))
                                .frame(
                                    width:  dotSize * 1.70,
                                    height: dotSize * 1.70
                                )
                        }

                        // Main dot
                        Circle()
                            .fill(
                                isToday
                                    ? Color.white
                                    : Color.white.opacity(isReminder ? 0.85 : 0.45)
                            )
                            .frame(
                                width:  isToday ? dotSize * 1.15 : dotSize,
                                height: isToday ? dotSize * 1.15 : dotSize
                            )
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: Divider
    private var dividerLine: some View {
        Rectangle()
            .fill(Color.white.opacity(0.20))
            .frame(maxWidth: .infinity)
            .frame(height: max(0.5, size * 0.003))
    }

    // MARK: Note lines — 3 text preview lines
    private var noteLinesSection: some View {
        VStack(alignment: .leading, spacing: size * 0.022) {
            noteLine(widthFraction: 1.00, opacity: 0.90)
            noteLine(widthFraction: 0.78, opacity: 0.60)
            noteLine(widthFraction: 0.52, opacity: 0.38)
        }
    }

    private func noteLine(widthFraction: CGFloat, opacity: Double) -> some View {
        Capsule()
            .fill(Color.white.opacity(opacity))
            .frame(width: symbolW * widthFraction, height: lineH)
    }
}

// MARK: - Preview
#Preview("App Icon — 512pt") {
    AppIconView(size: 512)
        .padding(40)
        .background(Color.gray.opacity(0.15))
}

#Preview("App Icon — 128pt") {
    HStack(spacing: 20) {
        AppIconView(size: 128)
        AppIconView(size: 64)
        AppIconView(size: 32)
    }
    .padding(40)
    .background(Color.gray.opacity(0.15))
}
