import SwiftUI
import SwiftData

// MARK: - 정렬 옵션 (캘린더 탭 전용)
private enum SortOrder: String, CaseIterable {
    case byDate     = "결제일순"
    case highestFee = "금액 높은순"
    case lowestFee  = "금액 낮은순"
}

// MARK: - 캘린더 메인 화면
struct CalendarView: View {
    // SwiftData에서 전체 구독을 가져온 뒤 Swift filter·sorted로 처리
    // → #Predicate는 enum 프로퍼티 비교 시 컴파일 오류 가능성이 있으므로 사용하지 않음
    @Query private var subscriptions: [Subscription]

    // 주간 이동 (0 = 이번 주, +1 = 다음 주, -1 = 지난 주)
    @State private var weekOffset: Int   = 0
    @State private var selectedDate: Date? = nil

    // 정렬·필터 상태
    @State private var sortOrder        = SortOrder.byDate
    @State private var selectedCategory = "전체"
    @State private var selectedCycleRaw = "전체"   // "전체" or BillingCycle.rawValue
    @State private var selectedRouteRaw = "전체"   // "전체" or PaymentRoute.rawValue

    // MARK: 주간 날짜 계산 (월~일)
    private var weekDates: [Date] {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        // Calendar weekday: Sun=1, Mon=2 ... Sat=7
        // 월요일 기준: daysFromMon = (weekday + 5) % 7 → 월=0, 화=1, ..., 일=6
        let weekday   = cal.component(.weekday, from: today)
        let daysFromMon = (weekday + 5) % 7
        let monday = cal.date(byAdding: .day,
                              value: -daysFromMon + weekOffset * 7,
                              to: today)!
        return (0...6).map { cal.date(byAdding: .day, value: $0, to: monday)! }
    }

    // MARK: 필터·정렬 적용 목록
    // 정렬과 필터가 동시에 적용됨
    private var filteredSubscriptions: [Subscription] {
        subscriptions
            .filter { sub in
                (selectedCategory == "전체" || sub.category == selectedCategory)
                && (selectedCycleRaw == "전체" || sub.billingCycle.rawValue == selectedCycleRaw)
                && (selectedRouteRaw == "전체" || sub.paymentRoute.rawValue == selectedRouteRaw)
            }
            .sorted { a, b in
                switch sortOrder {
                case .byDate:
                    // 결제일순: BillingCalculator 재사용
                    return BillingCalculator.nextBillingDate(for: a) <
                           BillingCalculator.nextBillingDate(for: b)
                case .highestFee:
                    return CostCalculator.monthlyEquivalent(a) >
                           CostCalculator.monthlyEquivalent(b)
                case .lowestFee:
                    return CostCalculator.monthlyEquivalent(a) <
                           CostCalculator.monthlyEquivalent(b)
                }
            }
    }

    // 날짜 선택 시 해당 날짜 결제 항목만 표시 (필터·정렬은 그대로 유지)
    private var displayedSubscriptions: [Subscription] {
        guard let selected = selectedDate else { return filteredSubscriptions }
        let cal = Calendar.current
        let startOf = cal.startOfDay(for: selected)
        return filteredSubscriptions.filter { sub in
            // BillingCalculator.nextBillingDate를 재사용해 결제일 판단
            cal.isDate(
                BillingCalculator.nextBillingDate(for: sub, from: startOf),
                inSameDayAs: startOf
            )
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 1. 주간 캘린더 스트립
                WeekCalendarStrip(
                    weekDates: weekDates,
                    selectedDate: $selectedDate,
                    subscriptions: subscriptions,
                    weekRangeText: weekRangeText,
                    onPrevious: {
                        weekOffset -= 1
                        selectedDate = nil
                    },
                    onNext: {
                        weekOffset += 1
                        selectedDate = nil
                    }
                )
                .background(Color(.secondarySystemBackground))

                // 2. 정렬·필터 바
                SortFilterBar(
                    sortOrder: $sortOrder,
                    selectedCategory: $selectedCategory,
                    selectedCycleRaw: $selectedCycleRaw,
                    selectedRouteRaw: $selectedRouteRaw
                )
                Divider()

                // 3. 구독 목록
                listSection
            }
            .navigationTitle("캘린더")
        }
    }

    // MARK: - 목록 영역
    @ViewBuilder
    private var listSection: some View {
        if subscriptions.isEmpty {
            ContentUnavailableView(
                "구독이 없어요",
                systemImage: "calendar",
                description: Text("구독 탭에서 구독을 추가해보세요")
            )
            .frame(maxHeight: .infinity)
        } else if displayedSubscriptions.isEmpty {
            // 필터·날짜 선택 조건에 맞는 구독 없음
            ContentUnavailableView(
                "조건에 맞는 구독이 없어요",
                systemImage: "magnifyingglass",
                description: Text("정렬·필터 조건이나 날짜를 바꿔보세요")
            )
            .frame(maxHeight: .infinity)
        } else {
            List(displayedSubscriptions) { sub in
                NavigationLink(destination: SubscriptionDetailView(subscription: sub)) {
                    CalendarSubRow(subscription: sub)
                }
            }
            .listStyle(.plain)
        }
    }

    // MARK: - 헬퍼
    private var weekRangeText: String {
        guard let first = weekDates.first, let last = weekDates.last else { return "" }
        let style = Date.FormatStyle()
            .month(.defaultDigits).day()
            .locale(Locale(identifier: "ko_KR"))
        return "\(first.formatted(style)) ~ \(last.formatted(style))"
    }
}

// MARK: - 주간 캘린더 스트립

private struct WeekCalendarStrip: View {
    let weekDates: [Date]
    @Binding var selectedDate: Date?
    let subscriptions: [Subscription]
    let weekRangeText: String
    let onPrevious: () -> Void
    let onNext: () -> Void

    private let cal = Calendar.current

    var body: some View {
        VStack(spacing: 8) {
            // 주 이동 버튼 + 날짜 범위
            HStack {
                Button(action: onPrevious) {
                    Image(systemName: "chevron.left")
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                Spacer()
                Text(weekRangeText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
            }
            .padding(.horizontal, 8)

            // 7일 셀
            HStack(spacing: 0) {
                ForEach(weekDates, id: \.self) { date in
                    DayCell(
                        date: date,
                        count: billingCount(on: date),
                        isToday: cal.isDateInToday(date),
                        isSelected: selectedDate.map {
                            cal.isDate($0, inSameDayAs: date)
                        } ?? false
                    )
                    .onTapGesture {
                        // 같은 날짜 재탭 → 선택 해제
                        if let sel = selectedDate, cal.isDate(sel, inSameDayAs: date) {
                            selectedDate = nil
                        } else {
                            selectedDate = date
                        }
                    }
                }
            }
        }
        .padding(.vertical, 10)
    }

    /// 특정 날짜에 결제되는 구독 수 (BillingCalculator 재사용)
    private func billingCount(on date: Date) -> Int {
        let startOf = cal.startOfDay(for: date)
        return subscriptions.filter { sub in
            cal.isDate(
                BillingCalculator.nextBillingDate(for: sub, from: startOf),
                inSameDayAs: startOf
            )
        }.count
    }
}

// MARK: - 날짜 셀

private struct DayCell: View {
    let date: Date
    let count: Int
    let isToday: Bool
    let isSelected: Bool

    private var dayNumber: Int {
        Calendar.current.component(.day, from: date)
    }

    // 한국어 요일 약자 (Calendar.weekday: Sun=1 ... Sat=7)
    private var weekdayName: String {
        ["일", "월", "화", "수", "목", "금", "토"][
            Calendar.current.component(.weekday, from: date) - 1
        ]
    }

    var body: some View {
        VStack(spacing: 4) {
            // 요일명
            Text(weekdayName)
                .font(.caption2)
                .foregroundStyle(isToday ? Color.blue : Color.secondary)

            // 날짜 숫자 (선택: 채운 원 / 오늘: 연한 원 / 그 외: 없음)
            ZStack {
                if isSelected {
                    Circle().fill(Color.blue).frame(width: 32, height: 32)
                } else if isToday {
                    Circle().fill(Color.blue.opacity(0.15)).frame(width: 32, height: 32)
                }
                Text("\(dayNumber)")
                    .font(.subheadline)
                    .fontWeight(isToday || isSelected ? .bold : .regular)
                    .foregroundStyle(
                        isSelected ? Color.white : (isToday ? Color.blue : Color.primary)
                    )
            }

            // 결제 건수 뱃지 (없으면 같은 높이 유지)
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Color.blue, in: Capsule())
            } else {
                Color.clear.frame(height: 14)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}

// MARK: - 정렬·필터 바

private struct SortFilterBar: View {
    @Binding var sortOrder: SortOrder
    @Binding var selectedCategory: String
    @Binding var selectedCycleRaw: String
    @Binding var selectedRouteRaw: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 정렬 Picker
                Menu {
                    Picker("정렬", selection: $sortOrder) {
                        ForEach(SortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                } label: {
                    FilterChip(
                        text: sortOrder.rawValue,
                        icon: "arrow.up.arrow.down",
                        isActive: sortOrder != .byDate
                    )
                }

                // 카테고리 필터
                Menu {
                    Picker("카테고리", selection: $selectedCategory) {
                        Text("전체").tag("전체")
                        ForEach(subscriptionCategories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                } label: {
                    FilterChip(
                        text: selectedCategory == "전체" ? "카테고리" : selectedCategory,
                        isActive: selectedCategory != "전체"
                    )
                }

                // 결제 주기 필터 (rawValue 문자열로 비교 — #Predicate 미사용)
                Menu {
                    Picker("결제 주기", selection: $selectedCycleRaw) {
                        Text("전체").tag("전체")
                        ForEach(BillingCycle.allCases, id: \.self) { cycle in
                            Text(cycle.rawValue).tag(cycle.rawValue)
                        }
                    }
                } label: {
                    FilterChip(
                        text: selectedCycleRaw == "전체" ? "결제 주기" : selectedCycleRaw,
                        isActive: selectedCycleRaw != "전체"
                    )
                }

                // 결제 경로 필터 (rawValue 문자열로 비교)
                Menu {
                    Picker("결제 경로", selection: $selectedRouteRaw) {
                        Text("전체").tag("전체")
                        ForEach(PaymentRoute.allCases, id: \.self) { route in
                            Text(route.rawValue).tag(route.rawValue)
                        }
                    }
                } label: {
                    FilterChip(
                        text: selectedRouteRaw == "전체" ? "결제 경로" : selectedRouteRaw,
                        isActive: selectedRouteRaw != "전체"
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - 필터 칩 (Menu 레이블용)

private struct FilterChip: View {
    let text: String
    var icon: String? = nil
    var isActive: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).font(.caption2) }
            Text(text).font(.caption).lineLimit(1)
            Image(systemName: "chevron.down").font(.caption2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            isActive ? Color.blue.opacity(0.15) : Color(.systemGray6),
            in: Capsule()
        )
        .foregroundStyle(isActive ? Color.blue : Color.primary)
    }
}

// MARK: - 캘린더 구독 행

private struct CalendarSubRow: View {
    let subscription: Subscription

    private var nextDate: Date      { BillingCalculator.nextBillingDate(for: subscription) }
    private var status: BillingStatus { BillingCalculator.billingStatus(for: subscription) }

    private var dateLabel: String {
        nextDate.formatted(
            .dateTime.month(.defaultDigits).day()
            .locale(Locale(identifier: "ko_KR"))
        )
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(subscription.name)
                    .font(.headline)
                Text(subscription.planName.isEmpty ? subscription.category
                                                   : subscription.planName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(CostCalculator.monthlyEquivalent(subscription).formatted())원")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                // 날짜 텍스트에 결제 임박 색상 적용
                Text(dateLabel)
                    .font(.caption)
                    .foregroundStyle(status.color)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    CalendarView()
        .modelContainer(for: [Account.self, Subscription.self], inMemory: true)
}
