import PegCore
import SwiftUI

struct CalendarCard: View {
    @ObservedObject var model: CalendarModel

    var body: some View {
        PanelCard {
            CardHeader(title: model.grid.title) {
                Image(systemName: "calendar")
                    .font(.system(size: 14))
            } trailing: {
                HStack(spacing: 8) {
                    navigationButton(symbol: "chevron.left", label: "前の月", action: model.showPreviousMonth)
                    Button(action: model.showCurrentMonth) {
                        Text("今日")
                            .font(.system(size: 11, weight: .semibold))
                            .fixedSize()
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, 8)
                            .frame(height: 24)
                            .background(Theme.raised)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    navigationButton(symbol: "chevron.right", label: "次の月", action: model.showNextMonth)
                }
            }
            MonthView(
                grid: model.grid,
                holidays: Set(model.holidays.keys),
                markedDays: model.calendarAccess == .granted ? model.markedDays : [],
                selectedDay: model.selectedDay,
                select: model.select
            )
            PanelDivider()
            agenda
        }
    }

    @ViewBuilder
    private var agenda: some View {
        switch model.calendarAccess {
        case .needsAccess:
            SectionLabel(text: "今日の予定")
            NoticeBox(
                symbol: "calendar.badge.exclamationmark",
                tint: Theme.textSecondary,
                title: "アクセス許可が必要です",
                detail: "許可すると予定を表示します",
                buttonTitle: "許可",
                isProminent: true,
                action: model.requestCalendarAccess
            )
        case .denied:
            SectionLabel(text: "今日の予定")
            NoticeBox(
                symbol: "calendar.badge.exclamationmark",
                tint: Theme.coral,
                title: "カレンダーを読み込めません",
                detail: "システム設定で許可してください",
                buttonTitle: "設定",
                isProminent: false,
                action: model.requestCalendarAccess
            )
        case .granted:
            VStack(alignment: .leading, spacing: 12) {
                if let day = model.selectedDay {
                    SectionLabel(text: ClockFormat.dayTitle(day) + "の予定")
                    AgendaList(model: model, events: model.selectedEvents, followsClock: false)
                } else {
                    SectionLabel(text: "今日の予定")
                    AgendaList(model: model, events: model.agenda.today, followsClock: true)
                    if !model.agenda.tomorrow.isEmpty {
                        SectionLabel(text: "明日")
                        AgendaList(model: model, events: model.agenda.tomorrow, followsClock: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func navigationButton(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 24, height: 24)
                .background(Theme.raised)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct MonthView: View {
    let grid: MonthGrid
    let holidays: Set<Date>
    let markedDays: Set<Date>
    let selectedDay: Date?
    let select: (MonthDay) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(ClockFormat.weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                    Text(symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(weekdayColor(index, fallback: Theme.textDim))
                        .frame(maxWidth: .infinity, minHeight: 24)
                }
            }
            ForEach(Array(grid.weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(week) { day in
                        Button {
                            select(day)
                        } label: {
                            cell(for: day)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func cell(for day: MonthDay) -> some View {
        let selected = selectedDay.map { Calendar.current.isDate(day.date, inSameDayAs: $0) } ?? false
        return Text(String(day.day))
            .font(.system(size: 12, weight: day.isToday || selected ? .bold : .medium, design: .monospaced))
            .foregroundStyle(selected ? Color.white : color(for: day))
            .frame(width: 28, height: 28)
            .background(day.isToday ? Theme.accent : selected ? Theme.amber.opacity(0.85) : Color.clear)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(selected ? Theme.amber : Color.clear, lineWidth: 2)
            )
            .overlay(alignment: .bottom) {
                Circle()
                    .fill(day.isToday ? Color.white : dotColor(for: day))
                    .frame(width: 3, height: 3)
                    .padding(.bottom, 3)
                    .opacity(markedDays.contains(day.date) ? 1 : 0)
            }
            .frame(maxWidth: .infinity, minHeight: 34)
            .contentShape(Rectangle())
    }

    private func dotColor(for day: MonthDay) -> Color {
        day.isInMonth ? Theme.accent : Theme.textDim
    }

    private func color(for day: MonthDay) -> Color {
        if day.isToday {
            return Color.white
        }
        if !day.isInMonth {
            return Theme.textDim
        }
        if holidays.contains(day.date) {
            return Theme.coral
        }
        return weekdayColor(day.weekday, fallback: Theme.textPrimary)
    }

    private func weekdayColor(_ index: Int, fallback: Color) -> Color {
        switch index {
        case 0:
            return Theme.coral
        case 6:
            return Theme.saturday
        default:
            return fallback
        }
    }
}

struct AgendaList: View {
    @ObservedObject var model: CalendarModel
    let events: [AgendaEvent]
    let followsClock: Bool

    var body: some View {
        if events.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textDim)
                Text("予定はありません")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 10)
            .frame(height: 44)
        } else {
            VStack(spacing: 4) {
                ForEach(events) { event in
                    AgendaRow(
                        event: event,
                        status: followsClock ? event.status(at: model.now) : .upcoming,
                        color: model.calendarColors[event.calendarID] ?? Theme.accent,
                        open: model.openMeet
                    )
                }
            }
        }
    }
}

struct AgendaRow: View {
    let event: AgendaEvent
    let status: AgendaEvent.Status
    let color: Color
    let open: (URL) -> Void

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .opacity(status == .past ? 0.4 : 1)
                .frame(width: 3, height: event.isAllDay ? 16 : 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: event.isAllDay ? 12 : 13, weight: status == .current ? .semibold : .medium))
                    .foregroundStyle(status == .past ? Theme.textDim : Theme.textPrimary)
                    .lineLimit(1)
                if !event.isAllDay {
                    Text(event.timeText())
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(status == .past ? Theme.textDim : Theme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let url = event.meetURL {
                MeetButton(status: status) {
                    open(url)
                }
            } else if event.isAllDay {
                Text("終日")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.textDim)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: event.isAllDay && event.meetURL == nil ? 28 : 44)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
    }

    private var background: Color {
        if status == .current {
            return Theme.accentSoft
        }
        if event.isAllDay {
            return Theme.raised
        }
        return Color.clear
    }
}

struct MeetButton: View {
    let status: AgendaEvent.Status
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "video")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(status == .current ? Color.white : Theme.textSecondary)
                Text("Meet")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(status == .current ? Color.white : Theme.textPrimary)
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(status == .current ? Theme.accent : Theme.raised)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusSmall)
                    .stroke(status == .current ? Color.clear : Theme.border, lineWidth: 1)
            )
            .opacity(status == .past ? 0.6 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Meet を開く")
    }
}
