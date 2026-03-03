/// EventPermissionView.swift
/// Phase 3: Permission request UI shown when calendar/reminders access is not granted.

import SwiftUI

struct EventPermissionView: View {
    let eventKit = EventKitService.shared

    @State private var requestingCalendar  = false
    @State private var requestingReminders = false

    var body: some View {
        VStack(spacing: NoCalTheme.spacing24) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.noCalAccent.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.noCalAccent)
            }

            VStack(spacing: NoCalTheme.spacing8) {
                Text("캘린더 & 미리알림 연동")
                    .font(.title3.weight(.bold))
                Text("nocal의 타임라인에서 Apple 캘린더 일정과\n미리알림을 함께 확인하고 관리하세요.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: NoCalTheme.spacing12) {
                // Calendar permission
                PermissionButton(
                    icon:     "calendar",
                    label:    "캘린더 접근 허용",
                    subtitle: "일정을 타임라인에서 보고 만들 수 있어요",
                    granted:  eventKit.hasCalendarAccess,
                    loading:  requestingCalendar
                ) {
                    requestingCalendar = true
                    Task {
                        await eventKit.requestCalendarAccess()
                        requestingCalendar = false
                    }
                }

                // Reminders permission
                PermissionButton(
                    icon:     "checklist",
                    label:    "미리알림 접근 허용",
                    subtitle: "미리알림을 타임라인에서 확인하고 완료 처리할 수 있어요",
                    granted:  eventKit.hasRemindersAccess,
                    loading:  requestingReminders
                ) {
                    requestingReminders = true
                    Task {
                        await eventKit.requestRemindersAccess()
                        requestingReminders = false
                    }
                }
            }

            // Skip
            Button("나중에 설정") { }
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(NoCalTheme.spacing24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
private struct PermissionButton: View {
    let icon:     String
    let label:    String
    let subtitle: String
    let granted:  Bool
    let loading:  Bool
    let action:   () -> Void

    var body: some View {
        Button(action: granted ? {} : action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(granted ? .green : Color.noCalAccent)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Group {
                    if loading {
                        ProgressView().controlSize(.small)
                    } else if granted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                            .font(.caption)
                    }
                }
            }
            .padding(12)
            .background(
                granted
                    ? Color.green.opacity(0.07)
                    : Color.noCalAccent.opacity(0.06),
                in: RoundedRectangle(cornerRadius: NoCalTheme.radiusMed)
            )
            .overlay(
                RoundedRectangle(cornerRadius: NoCalTheme.radiusMed)
                    .stroke(
                        granted ? Color.green.opacity(0.3) : Color.noCalAccent.opacity(0.2),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(granted || loading)
    }
}
