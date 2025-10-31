//
//  TagFlowLayout.swift
//  CardGenie
//
//  Shared flow layout for wrapping tag chips and metadata pills.
//

import SwiftUI

struct TagFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude

        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var widestLine: CGFloat = 0

        for subview in subviews {
            let subviewSize = subview.sizeThatFits(.unspecified)
            let requiredWidth = lineWidth == 0 ? subviewSize.width : lineWidth + spacing + subviewSize.width

            if requiredWidth > maxWidth, lineWidth > 0 {
                widestLine = max(widestLine, lineWidth)
                totalHeight += lineHeight + spacing
                lineWidth = subviewSize.width
                lineHeight = subviewSize.height
            } else {
                if lineWidth > 0 {
                    lineWidth += spacing
                }
                lineWidth += subviewSize.width
                lineHeight = max(lineHeight, subviewSize.height)
            }
        }

        if lineWidth > 0 {
            widestLine = max(widestLine, lineWidth)
            totalHeight += lineHeight
        }

        let finalWidth = maxWidth.isFinite ? min(widestLine, maxWidth) : widestLine
        return CGSize(width: finalWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let availableWidth = bounds.width > 0 ? bounds.width : (proposal.width ?? .greatestFiniteMagnitude)

        var x = bounds.minX
        var y = bounds.minY
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let requiredWidth = lineWidth == 0 ? size.width : lineWidth + spacing + size.width

            if requiredWidth > availableWidth, lineWidth > 0 {
                x = bounds.minX
                y += lineHeight + spacing
                lineWidth = 0
                lineHeight = 0
            }

            if lineWidth > 0 {
                x += spacing
                lineWidth += spacing
            }

            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: size.width, height: size.height))

            x += size.width
            lineWidth += size.width
            lineHeight = max(lineHeight, size.height)
        }
    }
}
