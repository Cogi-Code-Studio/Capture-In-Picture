import SwiftUI

struct SettingsMacroTab: View {
    @ObservedObject var viewModel: ContentViewModel
    @State private var activeMacroDragPayload: MacroDragPayload?
    @State private var previewDestinationStepID: AutomationMacroStep.ID?
    @State private var isTerminalMacroDropTargeted = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Macro Builder")
                        .font(.title2.weight(.semibold))

                    Text("Drag blocks into the flow, reorder them by dragging existing steps, and tune wait times. Repeat capture loops through this flow until it has saved the requested number of Capture steps.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(alignment: .top, spacing: 18) {
                    macroLibraryPanel
                        .frame(width: 280)

                    macroFlowPanel
                }

                macroHelpPanel
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var macroLibraryPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Blocks")
                .font(.headline)

            Text("Drag a block into the flow or click Add to append it.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                ForEach(AutomationMacroStep.Kind.allCases) { kind in
                    macroPaletteItem(for: kind)
                }
            }

            Divider()

            HStack(spacing: 10) {
                Button("Reset Default Flow") {
                    viewModel.resetMacroSteps()
                }
                .buttonStyle(.borderedProminent)

                Button("Clear Flow", role: .destructive) {
                    viewModel.clearMacroSteps()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var macroFlowPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Flow")
                        .font(.headline)

                    Text(viewModel.automationMacroStepCountDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Text("Current: \(viewModel.automationFlowSummary)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }

            Toggle(isOn: $viewModel.startWithCapture) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start With Capture")
                        .font(.headline)

                    Text("Capture once before the macro loop starts. That first capture replaces the first Capture node in the first pass.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(.switch)

            if viewModel.startWithCapture {
                startCapturePreviewCard
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if viewModel.macroSteps.isEmpty {
                emptyMacroDropZone
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(displayedMacroSteps.enumerated()), id: \.element.id) { index, step in
                        VStack(spacing: 8) {
                            macroInsertionIndicator(isActive: previewDestinationStepID == step.id)

                            macroStepCard(step, position: index + 1)
                                .dropDestination(for: String.self) { items, _ in
                                    handleMacroDrop(items, before: step.id)
                                } isTargeted: { isTargeted in
                                    updateMacroDropPreview(isTargeted: isTargeted, before: step.id)
                                }
                        }
                    }

                    appendMacroDropZone
                }
                .animation(.snappy(duration: 0.22, extraBounce: 0.04), value: displayedMacroSteps.map(\.id))
                .animation(.snappy(duration: 0.18, extraBounce: 0), value: previewDestinationStepID)
                .animation(.snappy(duration: 0.18, extraBounce: 0), value: isTerminalMacroDropTargeted)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var startCapturePreviewCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "camera.aperture")
                .foregroundStyle(.green)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text("Start Capture")
                    .font(.headline)

                Text("Runs once before the loop, then the rest of the flow continues.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Text("Global")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.12), in: Capsule())
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.green.opacity(0.2), lineWidth: 1)
        }
    }

    private var macroHelpPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How it runs")
                .font(.headline)

            Label("The app focuses the selected window first, then starts your macro flow.", systemImage: "macwindow")
            Label("If Start With Capture is on, the app saves one frame before the loop and treats it as the first Capture of the first pass.", systemImage: "camera.badge.clock")
            Label("A Capture block saves one screenshot. Repeat capture stops once the requested number of screenshots has been saved.", systemImage: "camera.aperture")
            Label("Use Wait when the target app needs time to respond before the next arrow key or capture.", systemImage: "timer")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var emptyMacroDropZone: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(isTerminalMacroDropTargeted ? Color.accentColor : .secondary)

            Text("Drop steps here to start the macro flow.")
                .font(.headline)

            Text("You can add at least one Capture block, then surround it with arrow keys and Wait blocks as needed.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding(20)
        .background(
            (isTerminalMacroDropTargeted ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor).opacity(0.45)),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    isTerminalMacroDropTargeted ? Color.accentColor.opacity(0.35) : Color.white.opacity(0),
                    lineWidth: isTerminalMacroDropTargeted ? 2 : 0
                )
        }
        .dropDestination(for: String.self) { items, _ in
            handleMacroDrop(items, before: nil)
        } isTargeted: { isTargeted in
            updateTerminalMacroDropPreview(isTargeted: isTargeted)
        }
    }

    private var appendMacroDropZone: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(
                isTerminalMacroDropTargeted
                    ? Color.accentColor.opacity(0.12)
                    : Color(nsColor: .controlBackgroundColor).opacity(0.28)
            )
            .frame(maxWidth: .infinity, minHeight: 74)
            .overlay {
                VStack(spacing: 6) {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(isTerminalMacroDropTargeted ? Color.accentColor : .secondary)

                    Text("Drop here to append")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(isTerminalMacroDropTargeted ? Color.accentColor : .secondary)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isTerminalMacroDropTargeted ? Color.accentColor.opacity(0.35) : Color.white.opacity(0),
                        lineWidth: isTerminalMacroDropTargeted ? 2 : 0
                    )
            }
            .dropDestination(for: String.self) { items, _ in
                handleMacroDrop(items, before: nil)
            } isTargeted: { isTargeted in
                updateTerminalMacroDropPreview(isTargeted: isTargeted)
            }
    }

    private func macroPaletteItem(for kind: AutomationMacroStep.Kind) -> some View {
        HStack(spacing: 12) {
            Image(systemName: kind.systemImage)
                .foregroundStyle(macroAccentColor(for: kind))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(kind.title)
                    .font(.headline)

                Text(kind.detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button("Add") {
                viewModel.addMacroStep(kind)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onDrag {
            macroItemProvider(for: MacroDragPayload(sourceStepID: nil, kind: kind))
        }
    }

    private func macroStepCard(_ step: AutomationMacroStep, position: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Text("\(position)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, alignment: .leading)

                Image(systemName: step.kind.systemImage)
                    .foregroundStyle(macroAccentColor(for: step.kind))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(step.kind.title)
                        .font(.headline)

                    Text(step.detailSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(.secondary)
                        .help("Drag to reorder")
                        .onDrag {
                            macroItemProvider(for: MacroDragPayload(sourceStepID: step.id, kind: step.kind))
                        }

                    Button {
                        viewModel.removeMacroStep(step.id)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }

            if step.isWait {
                HStack(spacing: 10) {
                    Text("Duration")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    TextField(
                        "0.6",
                        value: waitDurationBinding(for: step.id),
                        format: .number.precision(.fractionLength(1))
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)

                    Text("sec")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Stepper("", value: waitDurationBinding(for: step.id), in: 0.1...AutomationMacroStep.maxWaitDuration, step: 0.1)
                        .labelsHidden()
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.32), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(macroAccentColor(for: step.kind).opacity(0.18), lineWidth: 1)
        }
    }

    private func macroInsertionIndicator(isActive: Bool) -> some View {
        Capsule(style: .continuous)
            .fill(isActive ? Color.accentColor : Color.clear)
            .frame(maxWidth: .infinity)
            .frame(height: isActive ? 8 : 2)
            .opacity(isActive ? 1 : 0.001)
    }

    private var displayedMacroSteps: [AutomationMacroStep] {
        guard let sourceStepID = activeMacroDragPayload?.sourceStepID else {
            return viewModel.macroSteps
        }

        if let previewDestinationStepID {
            return reorderedMacroPreview(moving: sourceStepID, before: previewDestinationStepID)
        }

        if isTerminalMacroDropTargeted {
            return reorderedMacroPreview(moving: sourceStepID, before: nil)
        }

        return viewModel.macroSteps
    }

    private func waitDurationBinding(for stepID: AutomationMacroStep.ID) -> Binding<Double> {
        Binding(
            get: {
                viewModel.macroSteps.first(where: { $0.id == stepID })?.resolvedWaitDuration ?? AutomationMacroStep.defaultWaitDuration
            },
            set: { newValue in
                viewModel.updateMacroWaitDuration(for: stepID, seconds: newValue)
            }
        )
    }

    private func macroAccentColor(for kind: AutomationMacroStep.Kind) -> Color {
        switch kind {
        case .up:
            return .mint
        case .down:
            return .orange
        case .left:
            return .blue
        case .right:
            return .indigo
        case .wait:
            return .pink
        case .capture:
            return .green
        }
    }

    private func encodeMacroDragPayload(_ payload: MacroDragPayload) -> String {
        guard
            let data = try? JSONEncoder().encode(payload),
            let encodedString = String(data: data, encoding: .utf8)
        else {
            return ""
        }

        return encodedString
    }

    private func macroItemProvider(for payload: MacroDragPayload) -> NSItemProvider {
        activeMacroDragPayload = payload
        previewDestinationStepID = nil
        isTerminalMacroDropTargeted = false
        return NSItemProvider(object: encodeMacroDragPayload(payload) as NSString)
    }

    private func handleMacroDrop(_ items: [String], before destinationStepID: AutomationMacroStep.ID?) -> Bool {
        guard
            let item = items.first,
            let data = item.data(using: .utf8),
            let payload = try? JSONDecoder().decode(MacroDragPayload.self, from: data)
        else {
            return false
        }

        if let sourceStepID = payload.sourceStepID {
            withAnimation(.snappy(duration: 0.2, extraBounce: 0.04)) {
                viewModel.moveMacroStep(sourceStepID, before: destinationStepID)
            }
        } else {
            withAnimation(.snappy(duration: 0.2, extraBounce: 0.04)) {
                viewModel.addMacroStep(payload.kind, before: destinationStepID)
            }
        }

        clearMacroDragPreview()
        return true
    }

    private func updateMacroDropPreview(isTargeted: Bool, before destinationStepID: AutomationMacroStep.ID) {
        if isTargeted {
            withAnimation(.snappy(duration: 0.18, extraBounce: 0.02)) {
                previewDestinationStepID = destinationStepID
                isTerminalMacroDropTargeted = false
            }
        } else if previewDestinationStepID == destinationStepID {
            withAnimation(.snappy(duration: 0.18, extraBounce: 0)) {
                previewDestinationStepID = nil
            }
        }
    }

    private func updateTerminalMacroDropPreview(isTargeted: Bool) {
        if isTargeted {
            withAnimation(.snappy(duration: 0.18, extraBounce: 0.02)) {
                previewDestinationStepID = nil
                isTerminalMacroDropTargeted = true
            }
        } else if isTerminalMacroDropTargeted {
            withAnimation(.snappy(duration: 0.18, extraBounce: 0)) {
                isTerminalMacroDropTargeted = false
            }
        }
    }

    private func reorderedMacroPreview(
        moving sourceStepID: AutomationMacroStep.ID,
        before destinationStepID: AutomationMacroStep.ID?
    ) -> [AutomationMacroStep] {
        guard sourceStepID != destinationStepID else {
            return viewModel.macroSteps
        }

        var reorderedSteps = viewModel.macroSteps
        guard let sourceIndex = reorderedSteps.firstIndex(where: { $0.id == sourceStepID }) else {
            return reorderedSteps
        }

        let movedStep = reorderedSteps.remove(at: sourceIndex)
        let destinationIndex: Int

        if
            let destinationStepID,
            let resolvedDestinationIndex = reorderedSteps.firstIndex(where: { $0.id == destinationStepID })
        {
            destinationIndex = resolvedDestinationIndex
        } else {
            destinationIndex = reorderedSteps.endIndex
        }

        reorderedSteps.insert(movedStep, at: destinationIndex)
        return reorderedSteps
    }

    private func clearMacroDragPreview() {
        activeMacroDragPayload = nil
        previewDestinationStepID = nil
        isTerminalMacroDropTargeted = false
    }
}

private struct MacroDragPayload: Codable {
    let sourceStepID: AutomationMacroStep.ID?
    let kind: AutomationMacroStep.Kind
}
