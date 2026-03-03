# nocal — Note + Calendar

> 오늘의 생각(Note)과 시간(Calendar)을 하나의 흐름으로 연결하는 생산성 허브

| 플랫폼 | 최소 버전 |
|--------|---------|
| iOS | 17.0+ |
| macOS | 14.0+ |

---

## 기능 개요

### 노트 (Note)
- 실시간 마크다운 렌더링 (TextKit 2 기반)
- 체크박스 `- [ ]` / `- [x]` 토글 인터랙션
- `#태그` 자동 인식 및 태그 기반 필터링
- 폴더 트리 구조 + 고정(Pin) 기능
- 일일 노트 자동 생성 (날짜 기반)
- 6종 내장 템플릿 (일일/주간/회의록/아이디어/프로젝트/KPT)

### 캘린더 & 타임라인
- Apple 캘린더(EKEvent) 솔리드 블록 표시
- 미리알림(EKReminder) 양방향 동기화
- 24시간 타임라인에 할 일 배치 (타임블로킹)
- 노트 항목 → 타임라인 드래그 앤 드롭 추가

### 시스템 통합
- Siri / 단축어 지원 (App Intents)
  - "nocal에 메모 만들어줘"
  - "오늘 nocal 열어줘"
  - "nocal에서 노트 검색하기"
- 홈 화면 위젯 3종 (타임라인 / 할 일 / 최근 노트)
- iCloud 동기화 (CloudKit)
- macOS 메뉴 커맨드 + 키보드 단축키

---

## 기술 스택

| 영역 | 기술 |
|------|------|
| UI | SwiftUI (iOS / macOS 공유) |
| 데이터 | SwiftData |
| 캘린더 | EventKit |
| 동기화 | CloudKit |
| 위젯 | WidgetKit |
| Siri | App Intents |
| 아키텍처 | MVVM + `@Observable` |

---

## 프로젝트 구조

```
NoCal/
├── DesignSystem/
│   └── NoCalTheme.swift          # 색상·폰트·간격 상수
├── Models/
│   ├── Note.swift
│   ├── Folder.swift
│   ├── TimedTask.swift
│   └── NoteTemplate.swift
├── ViewModels/
│   └── AppViewModel.swift        # @Observable 앱 상태
├── Markdown/
│   ├── MarkdownRenderer.swift    # TextKit 2 구문 강조
│   └── MarkdownTextEditor.swift  # 크로스플랫폼 에디터
├── Services/
│   ├── EventKitService.swift     # 캘린더·미리알림 연동
│   ├── SyncService.swift         # CloudKit 상태 모니터링
│   └── WidgetDataService.swift   # 위젯 데이터 공유
├── Intents/
│   └── NoCalIntents.swift        # Siri App Intents
└── Views/
    ├── RootView.swift
    ├── Sidebar/
    ├── Notes/
    ├── Timeline/
    └── Templates/

NoCalWidget/                      # Widget Extension
├── NoCalWidgetBundle.swift
├── NoCalWidget.swift             # 3종 위젯 Provider
└── NoCalWidgetViews.swift
```

---

## 시작하기

### 필수 설정 (Xcode)

1. **EventKit 권한** — Target › Info:
   ```
   NSCalendarsFullAccessUsageDescription
   NSRemindersFullAccessUsageDescription
   ```

2. **iCloud** — Signing & Capabilities › + iCloud › CloudKit:
   - Container: `iCloud.com.bear3745.NoCal`

3. **App Groups** — Signing & Capabilities › + App Groups:
   - `group.com.bear3745.NoCal`

4. **Widget Extension** — File › New › Target › Widget Extension:
   - Product Name: `NoCalWidget`

### 빌드

```bash
open NoCal.xcodeproj
# Xcode에서 Run (⌘R)
```

---

## 개발 로드맵

| Phase | 내용 | 상태 |
|-------|------|------|
| 1 | 기반 설계, 디자인 시스템, SwiftData 모델 | ✅ |
| 2 | 마크다운 에디터, 태그 필터링 | ✅ |
| 3 | EventKit 연동, 타임라인, 타임블로킹 | ✅ |
| 4 | CloudKit 동기화, Siri, 위젯, 템플릿 | ✅ |
