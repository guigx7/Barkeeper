import SwiftUI

struct PermissionsView: View {
    @ObservedObject var model: PermissionsModel
    var onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 36))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Permissions").font(.title2.bold())
                    Text("Barkeeper needs these permissions to manage your menu bar.")
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 0) {
                ForEach(Permission.allCases) { permission in
                    PermissionRow(permission: permission, granted: model.granted[permission] == true)
                    if permission != Permission.allCases.last { Divider() }
                }
            }
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))

            Text("After granting Screen Recording, macOS may ask you to quit and reopen Barkeeper.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button(model.allGranted ? "Done" : "Continue") { onContinue() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.requiredGranted)
            }
        }
        .padding(20)
        .frame(width: 460)
        .onAppear { model.startPolling() }
        .onDisappear { model.stopPolling() }
    }
}

private struct PermissionRow: View {
    let permission: Permission
    let granted: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(granted ? .green : .orange)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(permission.title + (permission.isRequired ? "" : " (optional)")).bold()
                Text(permission.purpose).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            if granted {
                Text("Granted").foregroundStyle(.secondary)
            } else {
                Button("Grant…") { permission.request() }
            }
        }
        .padding(12)
    }
}
