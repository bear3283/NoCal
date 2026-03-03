/// NoteTemplate.swift
/// Phase 4: 노트 템플릿 SwiftData 모델.
/// 내장 템플릿 6종 + 사용자 커스텀 템플릿 저장.

import SwiftData
import Foundation

@Model
final class NoteTemplate {

    var id:         UUID    = UUID()
    var name:       String  = ""
    var icon:       String  = "doc.text"
    var titlePattern: String = ""   // 예: "{{date}} 일일 노트"
    var content:    String  = ""
    var isBuiltIn:  Bool    = false
    var sortOrder:  Int     = 0
    var createdAt:  Date    = Date()

    init(name:         String,
         icon:         String = "doc.text",
         titlePattern: String = "",
         content:      String,
         isBuiltIn:    Bool   = false,
         sortOrder:    Int    = 0) {
        self.name         = name
        self.icon         = icon
        self.titlePattern = titlePattern
        self.content      = content
        self.isBuiltIn    = isBuiltIn
        self.sortOrder    = sortOrder
    }

    // ──────────────────────────────────────────────────────────────────
    // MARK: Template Resolution
    // ──────────────────────────────────────────────────────────────────

    /// {{date}} 등 플레이스홀더를 실제 값으로 치환한 제목 반환
    var resolvedTitle: String {
        resolve(titlePattern.isEmpty ? name : titlePattern)
    }

    /// 플레이스홀더를 치환한 내용 반환
    var resolvedContent: String {
        resolve(content)
    }

    private func resolve(_ template: String) -> String {
        let now  = Date()
        let cal  = Calendar.current
        let fmt  = DateFormatter()

        var result = template

        // {{date}} — 오늘 날짜 (예: 2026-03-01)
        fmt.dateFormat = "yyyy-MM-dd"
        result = result.replacingOccurrences(of: "{{date}}", with: fmt.string(from: now))

        // {{time}} — 현재 시각 (예: 14:30)
        fmt.dateFormat = "HH:mm"
        result = result.replacingOccurrences(of: "{{time}}", with: fmt.string(from: now))

        // {{weekday}} — 요일 (예: 월요일)
        fmt.dateFormat = "EEEE"
        fmt.locale = Locale(identifier: "ko_KR")
        result = result.replacingOccurrences(of: "{{weekday}}", with: fmt.string(from: now))

        // {{week}} — 주차 (예: 9주차)
        let week = cal.component(.weekOfYear, from: now)
        result = result.replacingOccurrences(of: "{{week}}", with: "\(week)주차")

        // {{month}} — 월 (예: 3월)
        let month = cal.component(.month, from: now)
        result = result.replacingOccurrences(of: "{{month}}", with: "\(month)월")

        // {{year}} — 년도 (예: 2026)
        let year = cal.component(.year, from: now)
        result = result.replacingOccurrences(of: "{{year}}", with: "\(year)")

        return result
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// MARK: - Built-in Templates
// ──────────────────────────────────────────────────────────────────────────────

extension NoteTemplate {

    static var builtIns: [NoteTemplate] {[
        dailyTemplate,
        weeklyTemplate,
        meetingTemplate,
        ideaTemplate,
        projectTemplate,
        retrospectiveTemplate,
    ]}

    // ── 일일 노트 ────────────────────────────────────────────────────────
    static var dailyTemplate: NoteTemplate {
        NoteTemplate(
            name:         "일일 노트",
            icon:         "sun.max",
            titlePattern: "{{date}} {{weekday}}",
            content:      """
                          # {{date}} {{weekday}}

                          ## 오늘의 목표
                          - [ ]
                          - [ ]
                          - [ ]

                          ## 오늘 할 일
                          - [ ]
                          - [ ]

                          ## 메모

                          ## 오늘의 회고
                          > 잘한 점:
                          > 개선할 점:
                          > 내일 할 일:
                          """,
            isBuiltIn:    true,
            sortOrder:    0
        )
    }

    // ── 주간 계획 ────────────────────────────────────────────────────────
    static var weeklyTemplate: NoteTemplate {
        NoteTemplate(
            name:         "주간 계획",
            icon:         "calendar.badge.clock",
            titlePattern: "{{year}} {{week}} 주간 계획",
            content:      """
                          # {{year}} {{week}} 주간 계획

                          ## 이번 주 핵심 목표
                          1.
                          2.
                          3.

                          ## 요일별 계획
                          - **월**:
                          - **화**:
                          - **수**:
                          - **목**:
                          - **금**:

                          ## 이번 주 체크리스트
                          - [ ]
                          - [ ]
                          - [ ]

                          ## 지난 주 회고
                          >
                          """,
            isBuiltIn:    true,
            sortOrder:    1
        )
    }

    // ── 회의록 ───────────────────────────────────────────────────────────
    static var meetingTemplate: NoteTemplate {
        NoteTemplate(
            name:         "회의록",
            icon:         "person.3",
            titlePattern: "{{date}} 회의록",
            content:      """
                          # 회의록

                          **날짜**: {{date}} {{time}}
                          **참석자**:
                          **주제**:

                          ---

                          ## 안건
                          1.
                          2.

                          ## 논의 내용

                          ## 결정 사항
                          - [ ]
                          - [ ]

                          ## 다음 회의
                          - **일정**:
                          - **안건**:
                          """,
            isBuiltIn:    true,
            sortOrder:    2
        )
    }

    // ── 아이디어 메모 ─────────────────────────────────────────────────────
    static var ideaTemplate: NoteTemplate {
        NoteTemplate(
            name:         "아이디어",
            icon:         "lightbulb",
            titlePattern: "아이디어: ",
            content:      """
                          # 아이디어 💡

                          ## 한 줄 요약

                          ## 문제 정의
                          > 어떤 문제를 해결하나요?

                          ## 해결 방법

                          ## 장점
                          -

                          ## 고려할 점
                          -

                          ## 다음 단계
                          - [ ]
                          - [ ]
                          """,
            isBuiltIn:    true,
            sortOrder:    3
        )
    }

    // ── 프로젝트 계획 ─────────────────────────────────────────────────────
    static var projectTemplate: NoteTemplate {
        NoteTemplate(
            name:         "프로젝트 계획",
            icon:         "folder.badge.gearshape",
            titlePattern: "프로젝트: ",
            content:      """
                          # 프로젝트 계획

                          **시작일**: {{date}}
                          **목표 완료일**:
                          **상태**: 🟡 진행 중

                          ---

                          ## 목표

                          ## 범위 (Scope)
                          ### 포함
                          -

                          ### 미포함
                          -

                          ## 마일스톤
                          - [ ] Phase 1:
                          - [ ] Phase 2:
                          - [ ] Phase 3:

                          ## 리소스
                          -

                          ## 리스크
                          | 리스크 | 영향도 | 대응 방안 |
                          |--------|--------|----------|
                          |        |        |          |

                          ## 메모
                          """,
            isBuiltIn:    true,
            sortOrder:    4
        )
    }

    // ── 회고 ─────────────────────────────────────────────────────────────
    static var retrospectiveTemplate: NoteTemplate {
        NoteTemplate(
            name:         "회고 (KPT)",
            icon:         "arrow.trianglehead.clockwise",
            titlePattern: "{{date}} 회고",
            content:      """
                          # {{date}} 회고 (KPT)

                          ## Keep — 계속할 것
                          -

                          ## Problem — 문제점
                          -

                          ## Try — 시도할 것
                          - [ ]
                          - [ ]

                          ---

                          ## 이번 기간 배운 것

                          ## 감사한 것
                          1.
                          2.
                          3.
                          """,
            isBuiltIn:    true,
            sortOrder:    5
        )
    }
}
