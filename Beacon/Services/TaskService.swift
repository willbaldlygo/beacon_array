import Foundation
import SwiftUI
import Combine

class TaskService: ObservableObject {
    static let shared = TaskService()
    
    @Published var activeTasks: [String] = []
    
    private let tasksKey = "active_tasks_v1"
    
    private init() {
        loadTasks()
    }
    
    private func loadTasks() {
        if let savedTasks = UserDefaults.standard.stringArray(forKey: tasksKey) {
            activeTasks = savedTasks
        } else {
            // Default initial tasks if none exist
            activeTasks = [
                "Finish Beacon v1 (Focus: Context Optimization)",
                "Plan Forge Architecture"
            ]
        }
    }
    
    func addTask(_ task: String) {
        guard !task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        activeTasks.append(task)
        saveTasks()
    }
    
    func removeTask(at index: Int) {
        guard index >= 0 && index < activeTasks.count else { return }
        activeTasks.remove(at: index)
        saveTasks()
    }
    
    func moveTask(from source: IndexSet, to destination: Int) {
        activeTasks.move(fromOffsets: source, toOffset: destination)
        saveTasks()
    }
    
    private func saveTasks() {
        UserDefaults.standard.set(activeTasks, forKey: tasksKey)
    }
    
    func getFormattedTasks() -> String {
        guard !activeTasks.isEmpty else { return "" }
        
        var output = "## Active Tasks\n"
        for task in activeTasks {
            output += "- [ ] \(task)\n"
        }
        return output
    }
}
