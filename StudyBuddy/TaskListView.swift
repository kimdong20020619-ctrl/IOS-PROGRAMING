import SwiftUI
import SwiftData

@Model
final class StudyTask {
    var title: String
    var subject: String
    var isDone: Bool

    init(title: String, subject: String, isDone: Bool = false) {
        self.title = title
        self.subject = subject
        self.isDone = isDone
    }
}

struct TaskListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StudyTask.title) private var tasks: [StudyTask]

    @State private var newTitle = ""
    @State private var newSubject = "수학"
    let subjects = ["수학", "영어", "프로그래밍"]

    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    TextField("할 일을 입력하세요", text: $newTitle)
                        .textFieldStyle(.roundedBorder)
                    Picker("과목", selection: $newSubject) {
                        ForEach(subjects, id: \.self) { Text($0) }
                    }
                    Button(action: addTask) {
                        Image(systemName: "plus.circle.fill").font(.title2)
                    }
                }
                .padding(.horizontal)

                List {
                    ForEach(tasks) { task in
                        HStack {
                            Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(task.isDone ? .green : .blue)
                            Text(task.title).strikethrough(task.isDone)
                            Spacer()
                            Text(task.subject).font(.caption).foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { task.isDone.toggle() }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            modelContext.delete(tasks[index])
                        }
                    }
                }
            }
            .navigationTitle("할 일")
            .toolbar {
                Button("샘플 추가", action: addSamples)
            }
        }
    }

    func addTask() {
        let trimmed = newTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        modelContext.insert(StudyTask(title: trimmed, subject: newSubject))
        newTitle = ""
    }

    func addSamples() {
        let samples = [
            StudyTask(title: "미분방정식 3장 풀기", subject: "수학"),
            StudyTask(title: "선형대수 복습", subject: "수학", isDone: true),
            StudyTask(title: "영어 단어 50개", subject: "영어"),
            StudyTask(title: "SwiftUI 11장 실습", subject: "프로그래밍"),
            StudyTask(title: "Codable 연습문제", subject: "프로그래밍", isDone: true),
        ]
        samples.forEach { modelContext.insert($0) }
    }
}

#Preview {
    TaskListView()
        .modelContainer(for: StudyTask.self, inMemory: true)
}
