//
//  StoriesCarouselView.swift
//  UnderBro iOS
//
//  Carrusel horizontal de historias efímeras con anillos Liquid Glass
//  resplandecientes y soporte para "Tu historia" (+).
//

import SwiftUI

public struct StoriesCarouselView: View {
    public let stories: [Story]
    public var onSelectStory: ((Story) -> Void)? = nil
    public var onAddStory: (() -> Void)? = nil
    
    public init(
        stories: [Story],
        onSelectStory: ((Story) -> Void)? = nil,
        onAddStory: (() -> Void)? = nil
    ) {
        self.stories = stories
        self.onSelectStory = onSelectStory
        self.onAddStory = onAddStory
    }
    
    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                ForEach(stories) { story in
                    Button {
                        if story.isCurrentUser {
                            onAddStory?()
                        } else {
                            onSelectStory?(story)
                        }
                    } label: {
                        VStack(spacing: 8) {
                            PlaceholderAvatarView(
                                username: story.user.username,
                                size: 66,
                                hasNewStory: story.hasUnseenStory,
                                isMe: story.isCurrentUser,
                                isVerified: story.user.isVerified
                            )
                            
                            Text(story.isCurrentUser ? "Tu historia" : story.user.username)
                                .font(.caption.weight(story.hasUnseenStory ? .semibold : .regular))
                                .foregroundStyle(story.hasUnseenStory ? UBTheme.textPrimary : UBTheme.textSecondary)
                                .lineLimit(1)
                                .frame(width: 72)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }
}
