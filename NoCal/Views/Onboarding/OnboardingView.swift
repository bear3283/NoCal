/// OnboardingView.swift
/// 최초 실행 시 표시되는 4페이지 온보딩 화면.
/// UserDefaults "didCompletedOnboarding" 플래그로 한 번만 표시.

import SwiftUI

struct OnboardingView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "note.text.badge.plus",
            iconColor: Color.noCalAccent,
            title: "nocal에 오신 것을 환영합니다",
            subtitle: "노트와 캘린더를 하나의 흐름으로",
            description: "오늘의 생각, 할일, 일정을 한 곳에서 관리하세요.\nnocal은 마크다운 노트와 캘린더를 자연스럽게 연결합니다.",
            useAppIcon: true
        ),
        OnboardingPage(
            icon: "text.cursor",
            iconColor: .blue,
            title: "마크다운 에디터",
            subtitle: "Bear 스타일의 강력한 편집 경험",
            description: "# 제목, **굵게**, _기울임_, `코드`\n- [ ] 체크박스로 할일 관리\n#태그로 노트를 손쉽게 분류하세요."
        ),
        OnboardingPage(
            icon: "calendar.badge.plus",
            iconColor: .orange,
            title: "캘린더 연동",
            subtitle: "노트에서 바로 일정 추가",
            description: "@2026-03-15 14:00 회의 제목\n!2026-03-20 마감일\n\n위와 같이 입력하면 캘린더와\n미리알림에 자동으로 추가할 수 있어요."
        ),
        OnboardingPage(
            icon: "sparkles",
            iconColor: .purple,
            title: "준비 완료!",
            subtitle: "지금 바로 시작하세요",
            description: "오늘 일일 노트가 자동으로 생성되어 있어요.\n사이드바에서 폴더와 태그로 노트를 정리하고,\n타임라인으로 하루를 계획하세요."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Page content
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { idx in
                    pageView(pages[idx])
                        .tag(idx)
                }
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .never))
            #endif
            .animation(.easeInOut, value: currentPage)

            // Page indicator + buttons
            VStack(spacing: NoCalTheme.spacing20) {
                pageIndicator

                if currentPage < pages.count - 1 {
                    HStack {
                        Button("건너뛰기") {
                            complete()
                        }
                        .foregroundStyle(.secondary)
                        .buttonStyle(.plain)

                        Spacer()

                        Button {
                            withAnimation { currentPage += 1 }
                        } label: {
                            Text("다음")
                                .fontWeight(.semibold)
                                .frame(width: 100)
                                .padding(.vertical, 12)
                                .background(Color.noCalAccent, in: Capsule())
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, NoCalTheme.spacing20)
                } else {
                    Button {
                        complete()
                    } label: {
                        Text("시작하기")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.noCalAccent, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, NoCalTheme.spacing20)
                }
            }
            .padding(.bottom, NoCalTheme.spacing20)
        }
        #if os(macOS)
        .frame(width: 480, height: 520)
        #endif
    }

    // MARK: - Page View
    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: NoCalTheme.spacing20) {
            Spacer()

            // First page: show actual app icon; other pages: SF symbol
            Group {
                if page.useAppIcon {
                    AppIconView(size: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: Color.noCalAccent.opacity(0.35), radius: 18, y: 8)
                } else {
                    Image(systemName: page.icon)
                        .font(.system(size: 72, weight: .light))
                        .foregroundStyle(page.iconColor)
                }
            }
            .padding(.bottom, NoCalTheme.spacing8)

            VStack(spacing: NoCalTheme.spacing8) {
                Text(page.title)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text(page.description)
                .font(.body)
                .foregroundStyle(.primary.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, NoCalTheme.spacing20)

            Spacer()
        }
        .padding(.horizontal, NoCalTheme.spacing16)
    }

    // MARK: - Page Indicator
    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(pages.indices, id: \.self) { idx in
                Capsule()
                    .fill(idx == currentPage ? Color.noCalAccent : Color.secondary.opacity(0.3))
                    .frame(width: idx == currentPage ? 20 : 8, height: 8)
                    .animation(.spring(response: 0.3), value: currentPage)
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: - Complete
    private func complete() {
        UserDefaults.standard.set(true, forKey: "didCompletedOnboarding")
        dismiss()
    }
}

// MARK: - OnboardingPage Model
private struct OnboardingPage {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let description: String
    var useAppIcon: Bool = false
}

#Preview {
    OnboardingView()
}
