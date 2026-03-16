import Foundation

public enum Route: String, CaseIterable, Identifiable, Codable, Sendable {
    case injection
    case patchApply
    case patchRemove
    case gel
    case oral
    case sublingual

    public var id: Self { self }
}
