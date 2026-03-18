import SwiftUI
import UIKit

// MARK: - View Extension

extension View {
    /// Adds a vector-quality stroke outline around an SF Symbol by extracting its contour as a Path.
    func sfSymbolStroke(_ systemName: String, color: Color, lineWidth: CGFloat = 2) -> some View {
        modifier(SFSymbolStrokeModifier(systemName: systemName, strokeColor: color, lineWidth: lineWidth))
    }
}

// MARK: - Modifier

private struct SFSymbolStrokeModifier: ViewModifier {
    let systemName: String
    let strokeColor: Color
    let lineWidth: CGFloat

    private func extractPathAndSize() -> (Path, CGSize) {
        let renderSize: CGFloat = 100
        let config = UIImage.SymbolConfiguration(pointSize: renderSize)
        guard let uiImage = UIImage(systemName: systemName, withConfiguration: config)?
            .withTintColor(.white, renderingMode: .alwaysOriginal) else { return (Path(), .zero) }

        let size = uiImage.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        guard let cgImage = renderer.image(actions: { _ in
            uiImage.draw(in: CGRect(origin: .zero, size: size))
        }).cgImage else { return (Path(), .zero) }

        let w = cgImage.width, h = cgImage.height
        var alpha = [UInt8](repeating: 0, count: w * h)
        guard let ctx = CGContext(
            data: &alpha, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue
        ) else { return (Path(), .zero) }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))

        let cgPath = MarchingSquares.traceContours(alpha: alpha, width: w, height: h)
        return (Path(cgPath), size)
    }

    func body(content: Content) -> some View {
        let (symbolPath, imageSize) = extractPathAndSize()
        content.background(
            SFSymbolStrokeShape(basePath: symbolPath, imageSize: imageSize)
                .stroke(strokeColor, style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round))
        )
    }
}

// MARK: - Shape

private struct SFSymbolStrokeShape: Shape {
    let basePath: Path
    let imageSize: CGSize

    func path(in rect: CGRect) -> Path {
        guard imageSize.width > 0, imageSize.height > 0 else { return basePath }

        let scaleX = rect.width / imageSize.width
        let scaleY = rect.height / imageSize.height
        let scale = min(scaleX, scaleY)

        let offsetX = (rect.width - imageSize.width * scale) / 2 + rect.origin.x
        let offsetY = (rect.height - imageSize.height * scale) / 2 + rect.origin.y

        var transform = CGAffineTransform(scaleX: scale, y: scale)
            .concatenating(CGAffineTransform(translationX: offsetX, y: offsetY))
        return Path(basePath.cgPath.copy(using: &transform) ?? basePath.cgPath)
    }
}

// MARK: - Marching Squares (contour following)

private enum MarchingSquares {
    // exitDir[caseNum][entryEdge] → exitEdge
    // Edges: 0=top, 1=right, 2=bottom, 3=left; -1=invalid
    // swiftlint:disable comma
    static let exits: [[Int]] = [
        [-1,-1,-1,-1], //  0
        [ 3,-1,-1, 0], //  1: TL
        [ 1, 0,-1,-1], //  2: TR
        [-1, 3,-1, 1], //  3: TL+TR
        [-1, 2, 1,-1], //  4: BR
        [ 3, 2, 1, 0], //  5: saddle TL+BR
        [ 2,-1, 0,-1], //  6: TR+BR
        [-1,-1, 3, 2], //  7: TL+TR+BR
        [-1,-1, 3, 2], //  8: BL
        [ 2,-1, 0,-1], //  9: TL+BL
        [ 1, 0, 3, 2], // 10: saddle TR+BL
        [-1, 2, 1,-1], // 11: TL+TR+BL
        [-1, 3,-1, 1], // 12: BR+BL
        [ 1, 0,-1,-1], // 13: TL+BR+BL
        [ 3,-1,-1, 0], // 14: TR+BR+BL
        [-1,-1,-1,-1], // 15
    ]
    // swiftlint:enable comma

    static let stepDX = [0, 1, 0, -1]
    static let stepDY = [-1, 0, 1, 0]
    static let opposite = [2, 3, 0, 1]

    static func traceContours(alpha: [UInt8], width w: Int, height h: Int) -> CGPath {
        let path = CGMutablePath()
        let cellW = w - 1, cellH = h - 1
        let threshold: UInt8 = 128
        var usedEntries = [UInt8](repeating: 0, count: cellW * cellH)

        func caseAt(_ x: Int, _ y: Int) -> Int {
            (alpha[y * w + x] >= threshold ? 1 : 0) |
            (alpha[y * w + x + 1] >= threshold ? 2 : 0) |
            (alpha[(y + 1) * w + x + 1] >= threshold ? 4 : 0) |
            (alpha[(y + 1) * w + x] >= threshold ? 8 : 0)
        }

        func edgeMid(_ x: Int, _ y: Int, _ edge: Int) -> CGPoint {
            switch edge {
            case 0: CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y))
            case 1: CGPoint(x: CGFloat(x + 1), y: CGFloat(y) + 0.5)
            case 2: CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y + 1))
            default: CGPoint(x: CGFloat(x), y: CGFloat(y) + 0.5)
            }
        }

        for sy in 0..<cellH {
            for sx in 0..<cellW {
                let c = caseAt(sx, sy)
                if c == 0 || c == 15 { continue }

                var startEntry = -1
                for entry in 0..<4 where exits[c][entry] >= 0 {
                    if usedEntries[sy * cellW + sx] & (1 << entry) == 0 {
                        startEntry = entry
                        break
                    }
                }
                guard startEntry >= 0 else { continue }

                let startExit = exits[c][startEntry]
                guard startExit >= 0 else { continue }

                usedEntries[sy * cellW + sx] |= (1 << startEntry)

                var points = [edgeMid(sx, sy, startExit)]
                var cx = sx + stepDX[startExit]
                var cy = sy + stepDY[startExit]
                var entryDir = opposite[startExit]
                let maxIter = cellW * cellH * 2
                var iter = 0

                while iter < maxIter {
                    iter += 1
                    if cx == sx && cy == sy { break }
                    guard cx >= 0, cx < cellW, cy >= 0, cy < cellH else { break }

                    let c = caseAt(cx, cy)
                    let exitDir = exits[c][entryDir]
                    guard exitDir >= 0 else { break }

                    usedEntries[cy * cellW + cx] |= (1 << entryDir)
                    points.append(edgeMid(cx, cy, exitDir))

                    cx += stepDX[exitDir]
                    cy += stepDY[exitDir]
                    entryDir = opposite[exitDir]
                }

                if points.count >= 3 {
                    path.move(to: points[0])
                    for p in points.dropFirst() { path.addLine(to: p) }
                    path.closeSubpath()
                }
            }
        }

        return path
    }
}

#Preview {
    VStack(spacing: 20) {
        Image(systemName: "flask.fill")
            .font(.system(size: 30))
            .foregroundStyle(.pink)
            .sfSymbolStroke("flask.fill", color: .black, lineWidth: 3)

        Image(systemName: "flask.fill")
            .font(.system(size: 10))
            .foregroundStyle(.pink)
            .sfSymbolStroke("flask.fill", color: .white, lineWidth: 2)
    }
    .padding()
    .background(Color.gray.opacity(0.3))
}
