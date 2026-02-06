import Foundation
import SwiftData

enum MediaType: String, Codable, CaseIterable {
    case image
    case video
}

enum FitMode: String, Codable, CaseIterable {
    case fill
    case fit
    case stretch
    case center
    case tile
}

enum RuleScope: String, Codable, CaseIterable {
    case global
    case screen
}

enum RandomStrategy: String, Codable, CaseIterable {
    case uniform
    case weighted
    case avoidRecent
}

@Model
final class MediaItem {
    var id: UUID
    var typeRaw: String
    var fileURL: URL
    var bookmarkData: Data?
    var createdAt: Date
    var lastUsedAt: Date?

    var width: Double?
    var height: Double?
    var duration: Double?
    var frameRate: Double?
    var sizeBytes: Int64?

    var tags: String
    var rating: Int
    var isFavorite: Bool

    init(
        id: UUID = UUID(),
        type: MediaType,
        fileURL: URL,
        bookmarkData: Data? = nil,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil,
        width: Double? = nil,
        height: Double? = nil,
        duration: Double? = nil,
        frameRate: Double? = nil,
        sizeBytes: Int64? = nil,
        tags: String = "",
        rating: Int = 0,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.typeRaw = type.rawValue
        self.fileURL = fileURL
        self.bookmarkData = bookmarkData
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.width = width
        self.height = height
        self.duration = duration
        self.frameRate = frameRate
        self.sizeBytes = sizeBytes
        self.tags = tags
        self.rating = rating
        self.isFavorite = isFavorite
    }

    var type: MediaType {
        get { MediaType(rawValue: typeRaw) ?? .image }
        set { typeRaw = newValue.rawValue }
    }
}

@Model
final class Album {
    var id: UUID
    var name: String
    @Relationship(deleteRule: .nullify) var items: [MediaItem]

    init(id: UUID = UUID(), name: String, items: [MediaItem] = []) {
        self.id = id
        self.name = name
        self.items = items
    }
}

@Model
final class Rule {
    var id: UUID
    var scopeRaw: String
    var priority: Int
    var enabled: Bool
    var weekdaysRaw: String
    var startMinutes: Int?
    var endMinutes: Int?
    var randomStrategyRaw: String
    var mediaMixRatio: Double

    init(
        id: UUID = UUID(),
        scope: RuleScope = .global,
        priority: Int = 0,
        enabled: Bool = true,
        weekdaysRaw: String = "",
        startMinutes: Int? = nil,
        endMinutes: Int? = nil,
        randomStrategy: RandomStrategy = .uniform,
        mediaMixRatio: Double = 0.5
    ) {
        self.id = id
        self.scopeRaw = scope.rawValue
        self.priority = priority
        self.enabled = enabled
        self.weekdaysRaw = weekdaysRaw
        self.startMinutes = startMinutes
        self.endMinutes = endMinutes
        self.randomStrategyRaw = randomStrategy.rawValue
        self.mediaMixRatio = mediaMixRatio
    }

    var scope: RuleScope {
        get { RuleScope(rawValue: scopeRaw) ?? .global }
        set { scopeRaw = newValue.rawValue }
    }

    var randomStrategy: RandomStrategy {
        get { RandomStrategy(rawValue: randomStrategyRaw) ?? .uniform }
        set { randomStrategyRaw = newValue.rawValue }
    }
}

@Model
final class ScreenProfile {
    var id: UUID
    var screenID: String
    var preferredFitModeRaw: String
    @Relationship(deleteRule: .nullify) var preferredAlbum: Album?

    init(
        id: UUID = UUID(),
        screenID: String,
        preferredFitMode: FitMode = .fill,
        preferredAlbum: Album? = nil
    ) {
        self.id = id
        self.screenID = screenID
        self.preferredFitModeRaw = preferredFitMode.rawValue
        self.preferredAlbum = preferredAlbum
    }

    var preferredFitMode: FitMode {
        get { FitMode(rawValue: preferredFitModeRaw) ?? .fill }
        set { preferredFitModeRaw = newValue.rawValue }
    }
}

@Model
final class History {
    var id: UUID
    @Relationship(deleteRule: .nullify) var media: MediaItem?
    var screenID: String
    var appliedAt: Date
    var result: String
    var error: String?

    init(
        id: UUID = UUID(),
        media: MediaItem? = nil,
        screenID: String,
        appliedAt: Date = Date(),
        result: String,
        error: String? = nil
    ) {
        self.id = id
        self.media = media
        self.screenID = screenID
        self.appliedAt = appliedAt
        self.result = result
        self.error = error
    }
}
