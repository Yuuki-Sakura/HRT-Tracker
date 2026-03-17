import SwiftUI
import UIKit

/// UIKit touch overlay: raw touches for tooltip (zero delay), pinch for zoom.
/// Placed inside SwiftUI's `.chartOverlay` for chart proxy access.
struct ChartGestureOverlay: UIViewRepresentable {
    var onDrag: (_ location: CGPoint) -> Void
    var onDragEnd: () -> Void
    var onPinchStart: (_ center: CGPoint) -> Void
    var onPinchChange: (_ scale: CGFloat, _ panTranslation: CGSize) -> Void
    var onPinchEnd: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ChartTouchView {
        let view = ChartTouchView()
        view.coordinator = context.coordinator
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = true

        let pinch = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )
        pinch.cancelsTouchesInView = false
        pinch.delegate = context.coordinator
        view.addGestureRecognizer(pinch)

        return view
    }

    func updateUIView(_ uiView: ChartTouchView, context: Context) {
        context.coordinator.onDrag = onDrag
        context.coordinator.onDragEnd = onDragEnd
        context.coordinator.onPinchStart = onPinchStart
        context.coordinator.onPinchChange = onPinchChange
        context.coordinator.onPinchEnd = onPinchEnd
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onDrag: ((_ location: CGPoint) -> Void)?
        var onDragEnd: (() -> Void)?
        var onPinchStart: ((_ center: CGPoint) -> Void)?
        var onPinchChange: ((_ scale: CGFloat, _ panTranslation: CGSize) -> Void)?
        var onPinchEnd: (() -> Void)?

        var isPinching = false
        private var startCenter: CGPoint = .zero

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool { true }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard let view = gesture.view else { return }
            let center = gesture.location(in: view)

            switch gesture.state {
            case .began:
                isPinching = true
                startCenter = center
                onDragEnd?() // cancel tooltip
                onPinchStart?(center)
            case .changed:
                let pan = CGSize(
                    width: center.x - startCenter.x,
                    height: center.y - startCenter.y
                )
                onPinchChange?(gesture.scale, pan)
            case .ended, .cancelled, .failed:
                isPinching = false
                onPinchEnd?()
            default:
                break
            }
        }
    }
}

/// Custom UIView that uses raw touchesBegan/Moved/Ended for zero-delay tooltip.
class ChartTouchView: UIView {
    weak var coordinator: ChartGestureOverlay.Coordinator?
    private weak var parentScrollView: UIScrollView?

    private func findParentScrollView() -> UIScrollView? {
        var view: UIView? = superview
        while let v = view {
            if let sv = v as? UIScrollView { return sv }
            view = v.superview
        }
        return nil
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        parentScrollView = findParentScrollView()
    }

    private func clampedLocation(_ touches: Set<UITouch>) -> CGPoint? {
        guard let touch = touches.first else { return nil }
        let loc = touch.location(in: self)
        return CGPoint(
            x: max(0, min(bounds.width, loc.x)),
            y: max(0, min(bounds.height, loc.y))
        )
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard let coord = coordinator, !coord.isPinching,
              let loc = clampedLocation(touches) else { return }
        parentScrollView?.canCancelContentTouches = false
        coord.onDrag?(loc)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard let coord = coordinator, !coord.isPinching,
              let loc = clampedLocation(touches) else { return }
        coord.onDrag?(loc)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        parentScrollView?.canCancelContentTouches = true
        guard let coord = coordinator, !coord.isPinching else { return }
        coord.onDragEnd?()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        parentScrollView?.canCancelContentTouches = true
        guard let coord = coordinator, !coord.isPinching else { return }
        coord.onDragEnd?()
    }
}
