//
//  ContentView.swift
//  Clicker
//
//  Created by Rifqi Alfaizi on 03/06/26.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: ClickerViewModel
    
    @State private var selectedIndex: Int? = nil
    @State private var newStepName: String = ""
    @State private var delayStep: Int? = nil
    @State private var isHoveringAdd = false
    @State private var isHoveringToggle = false
    
    var body: some View {
        HStack(spacing: 0) {
            sidebarView
            
            // Divider separator
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)
                .edgesIgnoringSafeArea(.all)
            
            stepsListView
        }
        .frame(minWidth: 500, minHeight: 320)
        .background(.clear)
        .alert(viewModel.editingStepIndex != nil ? "Edit Step" : "Name this Step", isPresented: $viewModel.showNamingAlert) {
            TextField("e.g. click profile button", text: $newStepName)
            TextField("Default delay is 2 second", value: $delayStep, format: .number)
            Button("Cancel", role: .cancel) {
                viewModel.cancelPendingStep()
                newStepName = ""
                delayStep = nil
            }
            Button(viewModel.editingStepIndex != nil ? "Save" : "Add") {
                if let index = viewModel.editingStepIndex {
                    viewModel.savePendingStep(at: index, withName: newStepName, delay: delayStep ?? 2)
                } else {
                    viewModel.addPendingStep(withName: newStepName, delay: delayStep ?? 2)
                }
                newStepName = ""
                delayStep = nil
            }
        } message: {
            if let point = viewModel.pendingCoordinate {
                Text("Captured coordinate at X: \(Int(point.x)), Y: \(Int(point.y))")
            } else {
                Text("Please enter a name for the step.")
            }
        }
        .onChange(of: viewModel.showNamingAlert) { show in
            if show {
                if let index = viewModel.editingStepIndex {
                    let step = viewModel.steps[index]
                    newStepName = step.text
                    delayStep = step.delay
                } else {
                    newStepName = ""
                    delayStep = nil
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var sidebarView: some View {
        VStack(spacing: 24) {
            sidebarHeader
            
            Divider()
                .opacity(0.8)
            
            repeatConfigView
                        
            actionButtonsView
            
            // Status Box
            if viewModel.isRunning {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("Cycle \(viewModel.completedCycles + 1)\(viewModel.config.repeatCount > 0 ? "/\(viewModel.config.repeatCount)" : "")")
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(Color.green.opacity(0.12))
                .cornerRadius(12)
                .transition(.opacity)
            }
        }
        .frame(width: 180)
        .glassEffect(in: .rect(cornerRadius: 32.0))
    }
    
    private var sidebarHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 36))
            
            Text("Auto Clicker")
                .font(.headline)
                .fontWeight(.bold)
        }
        .padding(.top, 10)
    }
    
    private var repeatConfigView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Repeat Cycle", systemImage: "repeat")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                TextField("Times", value: $viewModel.config.repeatCount, format: .number)
                    .textFieldStyle(.plain)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .frame(width: 70)
                
                Text("cycles")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text("0 for continuous execution")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .opacity(0.6)
        }
    }
    
    private var actionButtonsView: some View {
        VStack(spacing: 0) {
            // Add Step Button
            Button(action: {
                viewModel.startRecordingStep()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isRecording ? "scope" : "plus.circle.fill")
                        .font(.headline)
                    Text(viewModel.isRecording ? "Clicking..." : "Add Step")
                        .fontWeight(.semibold)
                }
                .padding()
                .glassEffect()
                .padding(.vertical, 10)
//                .background(
//                    LinearGradient(
//                        colors: viewModel.isRecording ? [.orange, .red] : [.blue, .purple],
//                        startPoint: .leading,
//                        endPoint: .trailing
//                    )
//                )
//                .cornerRadius(8)
//                .shadow(color: (viewModel.isRecording ? Color.orange : Color.blue).opacity(0.2), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .scaleEffect(isHoveringAdd ? 1.02 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isHoveringAdd)
            .onHover { hovering in
                isHoveringAdd = hovering
            }
            
            // Run Steps Button
            Button(action: {
                viewModel.toggleClicking()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isRunning ? "stop.fill" : "play.fill")
                        .font(.headline)
                    Text(viewModel.isRunning ? "Stop" : "Run Steps")
                        .fontWeight(.semibold)
                }
                .padding()
                .glassEffect()
//                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .scaleEffect(isHoveringToggle ? 1.02 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isHoveringToggle)
            .onHover { hovering in
                isHoveringToggle = hovering
            }
        }
    }
    
    private var stepsListView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Steps Sequence")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .padding(.horizontal, 18)
                .padding(.top, 18)
            
            if viewModel.steps.isEmpty {
                emptyStepsView
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(viewModel.steps.enumerated()), id: \.offset) { index, step in
                            stepRowView(index: index, step: step)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
    
    private var emptyStepsView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
                .opacity(0.3)
            Text("No steps added yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Click 'Add Step' to map target locations.")
                .font(.caption)
                .foregroundColor(.secondary)
                .opacity(0.5)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
    }
    
    private func stepRowView(index: Int, step: StepModel) -> some View {
        let isSelected = selectedIndex == index
        
        return HStack(spacing: 12) {
            // Step Indicator
            Text("\(index + 1)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(isSelected ? .white : .secondary)
                .frame(width: 20, height: 20)
                .background(isSelected ? Color.blue : Color.white.opacity(0.08))
                .clipShape(Circle())
            
            // Coordinates and Description
            VStack(alignment: .leading, spacing: 2) {
                Text(step.text)
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    Label("X: \(step.x) Y: \(step.y)", systemImage: "scope")
                    Label("\(step.delay)s delay", systemImage: "clock")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Row buttons
            if isSelected {
                HStack(spacing: 6) {
                    Button(action: {
                        viewModel.editStep(at: index)
                    }) {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(5)
                            .background(Color.blue.opacity(0.8))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        viewModel.deleteStep(at: index)
                        selectedIndex = nil
                    }) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(5)
                            .background(Color.red.opacity(0.8))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.all, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.white.opacity(0.06) : Color.white.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.blue.opacity(0.35) : Color.white.opacity(0.05), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.15)) {
                selectedIndex = index
            }
        }
    }
}

#Preview {
    let viewModel = ClickerViewModel()
    viewModel.steps = [
        StepModel(text: "open app", x: 10, y: 20, delay: 0),
        StepModel(text: "click profile", x: 10, y: 20, delay: 0)
    ]
    return ContentView(viewModel: viewModel)
}
