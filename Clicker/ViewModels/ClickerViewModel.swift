import Foundation
import Combine
import CoreGraphics
import AppKit

class OverlayWindow: NSWindow {
    var onClick: (CGPoint?) -> Void
    
    init(onClick: @escaping (CGPoint?) -> Void) {
        self.onClick = onClick
        
        // Span across all active screens/displays
        var totalFrame = NSRect.zero
        for screen in NSScreen.screens {
            totalFrame = totalFrame.union(screen.frame)
        }
        if totalFrame == .zero {
            totalFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        }
        
        super.init(
            contentRect: totalFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // Color.black.opacity(0.01) makes the window catch clicks without obscuring the screen
        self.backgroundColor = NSColor.black.withAlphaComponent(0.01)
        self.isOpaque = false
        self.hasShadow = false
        self.level = .screenSaver // Float on top of everything
        self.ignoresMouseEvents = false
        self.isReleasedWhenClosed = false
        
        let contentView = NSView(frame: totalFrame)
        self.contentView = contentView
    }
    
    override func mouseDown(with event: NSEvent) {
        NSCursor.pop()
        if let cgEvent = event.cgEvent {
            onClick(cgEvent.location)
        } else {
            let point = event.locationInWindow
            let screenHeight = NSScreen.main?.frame.height ?? 1080
            onClick(CGPoint(x: point.x, y: screenHeight - point.y))
        }
        self.close()
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC key to cancel
            NSCursor.pop()
            onClick(nil)
            self.close()
        }
    }
    
    override var canBecomeKey: Bool {
        return true
    }
}

class ClickerViewModel: ObservableObject {
    @Published var config: ClickConfiguration {
        didSet {
            saveConfig()
        }
    }
    @Published var isRunning: Bool = false
    @Published var isRecording: Bool = false
    @Published var isDelaying: Bool = false
    @Published var steps: [StepModel] = [] {
        didSet {
            saveSteps()
        }
    }
    @Published var showNamingAlert: Bool = false
    @Published var pendingCoordinate: CGPoint? = nil
    @Published var editingStepIndex: Int? = nil
    @Published var completedCycles = 0
    
    private var overlayWindow: OverlayWindow?
    private var currentStepIndex = 0
    private var localMonitor: Any?
    private var globalMonitor: Any?
    
    init() {
        if let configData = UserDefaults.standard.data(forKey: "clicker_config"),
           let decodedConfig = try? JSONDecoder().decode(ClickConfiguration.self, from: configData) {
            self.config = decodedConfig
        } else {
            self.config = ClickConfiguration(xCoordinate: 0.0, yCoordinate: 0.0, repeatCount: 1)
        }
        
        if let stepsData = UserDefaults.standard.data(forKey: "clicker_steps"),
           let decodedSteps = try? JSONDecoder().decode([StepModel].self, from: stepsData) {
            self.steps = decodedSteps
        } else {
            self.steps = []
        }
    }
    
    func toggleClicking() {
        if isRunning {
            stopClicking()
        } else {
            startClicking()
        }
    }
    
    private func startClicking() {
        guard !steps.isEmpty else { return }
        isRunning = true
        isDelaying = true
        currentStepIndex = 0
        completedCycles = 0
        
        registerEscapeKeyMonitor()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self, self.isRunning else { return }
            self.isDelaying = false
            self.runNextStep()
        }
    }
    
    private func stopClicking() {
        isRunning = false
        isDelaying = false
        removeEscapeKeyMonitor()
    }
    
    private func registerEscapeKeyMonitor() {
        removeEscapeKeyMonitor()
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC key
                self?.stopClicking()
                return nil // consume the event
            }
            return event
        }
        
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC key
                self?.stopClicking()
            }
        }
    }
    
    private func removeEscapeKeyMonitor() {
        if let local = localMonitor {
            NSEvent.removeMonitor(local)
            localMonitor = nil
        }
        if let global = globalMonitor {
            NSEvent.removeMonitor(global)
            globalMonitor = nil
        }
    }
    
    private func runNextStep() {
        guard isRunning else { return }
        
        if currentStepIndex >= steps.count {
            currentStepIndex = 0
            completedCycles += 1
            if config.repeatCount > 0 && completedCycles >= config.repeatCount {
                stopClicking()
                return
            }
        }
        
        let step = steps[currentStepIndex]
        performClick(at: CGPoint(x: step.x, y: step.y))
        
        currentStepIndex += 1
        
        let delay = step.delay > 0 ? TimeInterval(step.delay) : 0.5
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.runNextStep()
        }
    }
    
    private func performClick(at point: CGPoint) {
        guard let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left),
              let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left) else {
            return
        }
        
        mouseDown.post(tap: .cghidEventTap)
        mouseUp.post(tap: .cghidEventTap)
    }
    
    func startRecordingStep() {
        stopRecording()
        isRecording = true
        
        // Use a crosshair cursor to signal target selection
        NSCursor.crosshair.push()
        
        let overlay = OverlayWindow { [weak self] point in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let point = point {
                    self.pendingCoordinate = point
                    self.showNamingAlert = true
                } else {
                    self.isRecording = false
                }
                self.overlayWindow = nil
            }
        }
        
        self.overlayWindow = overlay
        overlay.makeKeyAndOrderFront(nil)
    }
    
    func editStep(at index: Int) {
        stopRecording()
        isRecording = true
        editingStepIndex = index
        
        // Use a crosshair cursor to signal target selection
        NSCursor.crosshair.push()
        
        let overlay = OverlayWindow { [weak self] point in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let point = point {
                    self.pendingCoordinate = point
                    self.showNamingAlert = true
                } else {
                    self.isRecording = false
                    self.editingStepIndex = nil
                }
                self.overlayWindow = nil
            }
        }
        
        self.overlayWindow = overlay
        overlay.makeKeyAndOrderFront(nil)
    }
    
    func addPendingStep(withName name: String, delay: Int = 1) {
        guard let point = pendingCoordinate else { return }
        let stepName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Step \(steps.count + 1)" : name
        let newStep = StepModel(text: stepName, x: Int(point.x), y: Int(point.y), delay: delay)
        steps.append(newStep)
        
        pendingCoordinate = nil
        showNamingAlert = false
        isRecording = false
        editingStepIndex = nil
    }
    
    func savePendingStep(at index: Int, withName name: String, delay: Int) {
        guard let point = pendingCoordinate else { return }
        guard index >= 0 && index < steps.count else { return }
        
        let stepName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Step \(index + 1)" : name
        steps[index] = StepModel(text: stepName, x: Int(point.x), y: Int(point.y), delay: delay)
        
        pendingCoordinate = nil
        showNamingAlert = false
        isRecording = false
        editingStepIndex = nil
    }
    
    func cancelPendingStep() {
        pendingCoordinate = nil
        showNamingAlert = false
        isRecording = false
        editingStepIndex = nil
    }
    
    func stopRecording() {
        isRecording = false
        if let window = overlayWindow {
            NSCursor.pop()
            window.close()
            overlayWindow = nil
        }
    }
    
    func deleteStep(at index: Int) {
        guard index >= 0 && index < steps.count else { return }
        steps.remove(at: index)
    }
    
    private func saveConfig() {
        if let encoded = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(encoded, forKey: "clicker_config")
        }
    }
    
    private func saveSteps() {
        if let encoded = try? JSONEncoder().encode(steps) {
            UserDefaults.standard.set(encoded, forKey: "clicker_steps")
        }
    }
}
