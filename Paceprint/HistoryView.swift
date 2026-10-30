import SwiftData
import SwiftUI

/// History: every saved Run, newest first. A Run still being recorded isn't one.
struct HistoryView: View {
    @Query(filter: Run.finished, sort: \Run.startDate, order: .reverse) private var runs: [Run]

    var body: some View {
        List(runs) { run in
            NavigationLink {
                SummaryView(run: run)
            } label: {
                HStack {
                    Text(run.startDate, format: .dateTime.month(.abbreviated).day().hour().minute())
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Spacer()
                    Text("\(RunFormat.kilometres(run.distance)) KM")
                        .font(.body.monospacedDigit().weight(.semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
            }
        }
        .navigationTitle("History")
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
    .modelContainer(for: Run.self, inMemory: true)
    .preferredColorScheme(.dark)
}
