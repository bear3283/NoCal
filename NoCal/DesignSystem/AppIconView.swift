/// AppIconView.swift
/// NoCal 앱 아이콘 — 캘린더 카드 v5
///
/// 디자인:
///   배경: 딥 인디고 그라디언트
///   글로우: 우상단 화이트 방사형 광원
///   캘린더 카드 (글래스 전체가 캘린더):
///     ┌─ 헤더 ─────────────────────────────────┐
///     │  ○                                ○    │  ← 바인딩 링 (어두운 인디고 배경)
///     ├─────────────────────────────────────── ┤
///     │  · · · · ·                             │
///     │  · · ◉ · ·   ← 오늘 (흰 원 강조)       │  ← 날짜 도트 그리드 5×3
///     │  · · · · ·                             │
///     ├─ 구분선 ──────────────────────────────  ┤
///     │  ○ ─────────────────────────           │
///     │  ○ ─────────────────────────           │  ← 미리알림 스트로크 × 3
///     │  ○ ─────────────────────────           │
///     └────────────────────────────────────────┘

import SwiftUI

struct AppIconView: View {

    /// 렌더링 크기 (기본 512pt)
    var size: CGFloat = 512

    // ── Derived metrics ──────────────────────────────────────────────────
    private var iconRadius: CGFloat { size * 0.2237 }
    private var cardRadius: CGFloat { size * 0.105  }
    private var cardW:      CGFloat { size * 0.680  }
    private var cardH:      CGFloat { size * 0.760  }

    // Calendar header (dark section at top of card)
    private var headerH:    CGFloat { size * 0.138  }
    private var ringD:      CGFloat { size * 0.044  }

    // Date grid
    private var dotD:       CGFloat { size * 0.028  }   // regular date dot
    private var todayD:     CGFloat { size * 0.054  }   // today circle diameter
    private var colSp:      CGFloat { size * 0.046  }   // column spacing
    private var rowSp:      CGFloat { size * 0.036  }   // row spacing

    // Reminder rows
    private var bulletD:    CGFloat { size * 0.046  }
    private var lineH:      CGFloat { size * 0.024  }

    // ── Body ─────────────────────────────────────────────────────────────
    var body: some View {
        ZStack {
            backgroundLayer
            glowLayer
            calendarCard
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

    // ── Calendar card — glass card + calendar content ─────────────────────
    private var calendarCard: some View {
        ZStack(alignment: .top) {
            // 1. Glass base
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .fill(Color.white.opacity(0.10))

            // 2. Dark header fill (clipped by card's rounded corners)
            VStack(spacing: 0) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hue: 0.658, saturation: 0.84, brightness: 0.44),
                                Color(hue: 0.678, saturation: 0.94, brightness: 0.27),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: headerH)
                    .overlay(alignment: .bottom) {
                        // Subtle separator under header
                        Rectangle()
                            .fill(Color.white.opacity(0.14))
                            .frame(height: max(0.5, size * 0.002))
                    }
                Spacer(minLength: 0)
            }

            // 3. Glass border
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.50),
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.04),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: max(1, size * 0.005)
                )

            // 4. Card content
            VStack(spacing: 0) {
                // Header: binding rings
                HStack {
                    bindingRing
                    Spacer()
                    bindingRing
                }
                .padding(.horizontal, cardW * 0.13)
                .frame(height: headerH)

                // Date grid
                dateGrid
                    .padding(.top, size * 0.034)

                // Divider
                Capsule()
                    .fill(Color.white.opacity(0.20))
                    .frame(height: max(1, size * 0.003))
                    .padding(.top, size * 0.030)

                // Reminder rows
                reminderRows
                    .padding(.top, size * 0.028)

                Spacer(minLength: size * 0.032)
            }
            .padding(.horizontal, cardW * 0.11)
        }
        .frame(width: cardW, height: cardH)
        .clipShape(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
    }

    // ── Binding ring ─────────────────────────────────────────────────────
    private var bindingRing: some View {
        ZStack {
            Circle()
                .fill(Color(hue: 0.675, saturation: 0.90, brightness: 0.22))
            Circle()
                .strokeBorder(Color.white.opacity(0.65), lineWidth: max(1.5, size * 0.007))
        }
        .frame(width: ringD, height: ringD)
    }

    // ── Date grid: 5 columns × 3 rows, row 1 col 2 = today ───────────────
    private var dateGrid: some View {
        VStack(spacing: rowSp) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: colSp) {
                    ForEach(0..<5, id: \.self) { col in
                        dateDot(row: row, col: col)
                    }
                }
            }
        }
    }

    private func dateDot(row: Int, col: Int) -> some View {
        let isToday = (row == 1 && col == 2)
        // Past row slightly dimmer; future rows slightly brighter
        let opacity: Double = row == 0 ? 0.35 : 0.52
        return ZStack {
            if isToday {
                Circle()
                    .fill(Color.white)
                    .frame(width: todayD, height: todayD)
            } else {
                Circle()
                    .fill(Color.white.opacity(opacity))
                    .frame(width: dotD, height: dotD)
            }
        }
        // Fixed cell keeps all columns aligned regardless of dot size
        .frame(width: todayD, height: todayD)
    }

    // ── Reminder rows ─────────────────────────────────────────────────────
    private var reminderRows: some View {
        VStack(alignment: .leading, spacing: size * 0.036) {
            reminderRow
            reminderRow
            reminderRow
        }
    }

    private var reminderRow: some View {
        HStack(spacing: size * 0.022) {
            Circle()
                .strokeBorder(Color.white.opacity(0.80), lineWidth: max(1, size * 0.008))
                .frame(width: bulletD, height: bulletD)
            Capsule()
                .fill(Color.white.opacity(0.72))
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
