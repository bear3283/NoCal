/// AppIconView.swift
/// NoCal 앱 아이콘 — 글래스모피즘 + 인디고 단색 (v2 단순화)
///
/// 디자인:
///   배경: 딥 인디고 그라디언트
///   글로우: 우상단 화이트 방사형 광원
///   글래스 카드: 화이트 12%, 그라디언트 테두리 (틸트 없음, 정중앙)
///   심볼:
///     ① 캘린더 Today 원 (강조 서클 + 외곽 헤일로 링)
///     ─ 구분선
///     ○ ─────────  (TODO 줄 × 3, 동일 길이, 왼쪽 미리알림 원형 불릿)
///     ○ ─────────
///     ○ ─────────

import SwiftUI

struct AppIconView: View {

    /// 렌더링 크기 (기본 512pt)
    var size: CGFloat = 512

    // ── Derived metrics ──────────────────────────────────────────────────
    private var iconRadius: CGFloat { size * 0.2237 }  // iOS 표준 비율
    private var cardRadius: CGFloat { size * 0.105  }
    private var cardW:      CGFloat { size * 0.650  }
    private var cardH:      CGFloat { size * 0.720  }

    private var symbolW:    CGFloat { size * 0.500  }
    private var bulletD:    CGFloat { size * 0.050  }  // TODO 불릿 지름
    private var headerH:    CGFloat { size * 0.058  }  // 캘린더 헤더 높이
    private var ringD:      CGFloat { size * 0.044  }  // 바인딩 링 지름
    private var lineH:      CGFloat { size * 0.026  }  // 라인 높이

    // ── Body ─────────────────────────────────────────────────────────────
    var body: some View {
        ZStack {
            backgroundLayer
            glowLayer
            glassCard
                .frame(width: cardW, height: cardH)   // 틸트 없음
            symbolLayer
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: iconRadius, style: .continuous))
    }

    // ── Background ───────────────────────────────────────────────────────
    private var backgroundLayer: some View {
        LinearGradient(
            stops: [
                .init(color: Color(hue: 0.660, saturation: 0.78, brightness: 0.56), location: 0.00),
                .init(color: Color(hue: 0.675, saturation: 0.90, brightness: 0.38), location: 0.55),
                .init(color: Color(hue: 0.698, saturation: 0.96, brightness: 0.22), location: 1.00),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // ── Ambient glow ─────────────────────────────────────────────────────
    private var glowLayer: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color.white.opacity(0.22), Color.clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.38
                )
            )
            .frame(width: size * 0.76, height: size * 0.76)
            .offset(x: size * 0.24, y: -size * 0.24)
    }

    // ── Glassmorphism card ────────────────────────────────────────────────
    private var glassCard: some View {
        RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
            .fill(Color.white.opacity(0.11))
            .overlay(alignment: .topLeading) {
                // Inner sheen (light source reflection on glass surface)
                RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.16), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                    )
                    .padding(max(1, size * 0.004))
            }
            .overlay(
                // Glass edge (bright top-left → dim bottom-right)
                RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.52),
                                Color.white.opacity(0.20),
                                Color.white.opacity(0.04),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: max(1, size * 0.005)
                    )
            )
    }

    // ── Symbol ───────────────────────────────────────────────────────────
    private var symbolLayer: some View {
        VStack(spacing: size * 0.050) {
            calendarHeader
            dividerLine
            todoLines
        }
        .frame(width: symbolW)
    }

    // MARK: Calendar header — binding rings + header bar (flip-calendar style)
    private var calendarHeader: some View {
        ZStack(alignment: .top) {
            // Header bar (below rings)
            RoundedRectangle(cornerRadius: size * 0.018, style: .continuous)
                .fill(Color.white.opacity(0.88))
                .frame(height: headerH)
                .padding(.top, ringD * 0.55)   // bar starts below ring center

            // Binding rings row (overlaps top of bar)
            HStack {
                bindingRing
                Spacer()
                bindingRing
            }
            .padding(.horizontal, symbolW * 0.10)
        }
    }

    private var bindingRing: some View {
        ZStack {
            // Dark fill — punches through the header bar visually
            Circle()
                .fill(Color(hue: 0.675, saturation: 0.88, brightness: 0.34))
            // White ring stroke
            Circle()
                .strokeBorder(Color.white.opacity(0.75), lineWidth: max(1.5, size * 0.007))
        }
        .frame(width: ringD, height: ringD)
    }

    // MARK: Divider
    private var dividerLine: some View {
        Capsule()
            .fill(Color.white.opacity(0.18))
            .frame(maxWidth: .infinity)
            .frame(height: max(1, size * 0.003))
    }

    // MARK: TODO lines — circle bullet + equal-width capsule
    private var todoLines: some View {
        VStack(alignment: .leading, spacing: size * 0.044) {
            todoRow
            todoRow
            todoRow
        }
    }

    private var todoRow: some View {
        HStack(spacing: size * 0.026) {
            // Reminder-style ring bullet (like iOS Reminders circle)
            Circle()
                .strokeBorder(Color.white.opacity(0.82), lineWidth: max(1, size * 0.008))
                .frame(width: bulletD, height: bulletD)

            // Line — full remaining width (all 3 rows same length)
            Capsule()
                .fill(Color.white.opacity(0.78))
                .frame(height: lineH)
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Previews
#Preview("512pt") {
    AppIconView(size: 512)
        .padding(32)
        .background(Color(white: 0.12))
}

#Preview("Multi-size") {
    HStack(spacing: 24) {
        AppIconView(size: 120)
        AppIconView(size: 72)
        AppIconView(size: 40)
    }
    .padding(32)
    .background(Color(white: 0.12))
}
