import KaffCore
import SwiftUI

/// Boissons personnalisées : liste (glisser pour supprimer) + feuille de création.
struct CustomDrinkEditorView: View {
    @Environment(AppModel.self) private var model
    @State private var isAdding = false
    @State private var deleteCount = 0

    var body: some View {
        List {
            if model.customDrinks.isEmpty {
                Text("Aucune boisson personnalisée.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }
            ForEach(model.customDrinks) { drink in
                HStack(spacing: 8) {
                    Image(systemName: "mug.fill").foregroundStyle(Theme.accent)
                    Text(drink.name).lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 4)
                    Text(drink.portionLabel)
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deleteCount += 1
                        Task { await model.deleteCustomDrink(id: drink.id) }
                    } label: {
                        Label("Supprimer", systemImage: "trash.fill")
                    }
                }
            }
            Button { isAdding = true } label: {
                Label("Nouvelle boisson", systemImage: "plus")
            }
            .tint(Theme.accent)
        }
        .navigationTitle("Boissons")
        .sensoryFeedback(.impact(weight: .light), trigger: deleteCount)
        .sheet(isPresented: $isAdding) {
            NavigationStack {
                CustomDrinkForm { drink in
                    Task { await model.save(customDrink: drink) }
                    isAdding = false
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Annuler", systemImage: "xmark") { isAdding = false }
                    }
                }
            }
        }
    }
}

/// Feuille de création : nom, puis caféine et volume sur des cadrans couronne.
private struct CustomDrinkForm: View {
    let onSave: (Drink) -> Void

    @State private var name = ""
    @State private var milligrams = Theme.Dial.defaultMilligrams
    @State private var volumeML = 250.0

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        Form {
            TextField("Nom", text: $name)
            NavigationLink {
                ValueDialView(title: "Caféine", symbol: "cup.and.saucer.fill", tint: Theme.accent, value: $milligrams,
                              range: Theme.Dial.milligramsRange, step: Theme.Dial.milligramsStep, format: Formatters.mg)
            } label: {
                LabeledContent("Caféine") {
                    Text(Formatters.mg(milligrams)).monospacedDigit().foregroundStyle(Theme.accent)
                }
            }
            NavigationLink {
                ValueDialView(title: "Volume", symbol: "drop.fill", tint: Theme.accent, value: $volumeML,
                              range: Theme.Dial.volumeRange, step: Theme.Dial.volumeStep, format: Formatters.ml)
            } label: {
                LabeledContent("Volume") {
                    Text(Formatters.ml(volumeML)).monospacedDigit().foregroundStyle(Theme.accent)
                }
            }
            Button {
                onSave(Drink(id: "custom-\(UUID().uuidString)", name: trimmedName,
                             milligrams: milligrams, volumeML: volumeML, symbol: "mug.fill", isCustom: true))
            } label: {
                Label("Enregistrer", systemImage: "checkmark").frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.accent)
            .disabled(trimmedName.isEmpty)
            .listRowBackground(Color.clear)
        }
        .navigationTitle("Nouvelle")
    }
}
