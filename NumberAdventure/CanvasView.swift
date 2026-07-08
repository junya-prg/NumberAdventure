import SwiftUI
import PencilKit

struct CanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var clearTrigger: Bool
    var isReadOnly: Bool = false
    @Environment(\.colorScheme) var colorScheme
    
    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .clear
        canvasView.isScrollEnabled = false
        canvasView.bounces = false
        canvasView.isUserInteractionEnabled = !isReadOnly
        canvasView.delegate = context.coordinator
        updateInk(for: canvasView)
        return canvasView
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // 【決定的バグ修正】
        // SwiftUI は View を再レンダリングするたびに新しい CanvasView 構造体を生成しますが、
        // Coordinator は再利用されます。coordinator.parent は古い構造体を指しているため、
        // そこに含まれる @Binding が無効（デッド）になり、canvasViewDrawingDidChange で
        // 書き込んでも親の State が一切更新されません。
        // ここで coordinator.parent を最新の self に差し替えることで、Binding を常に有効に保ちます。
        context.coordinator.parent = self
        
        // バインディングが指すデータが更新されたとき（切り替え時など）に描画を反映する
        if uiView.drawing.strokes.count != drawing.strokes.count || uiView.drawing.bounds != drawing.bounds {
            uiView.drawing = drawing
        }
        
        // clearTrigger が変化した時のみキャンバスをクリアする
        if context.coordinator.lastClearTrigger != clearTrigger {
            context.coordinator.lastClearTrigger = clearTrigger
            uiView.drawing = PKDrawing()
            // 親の drawing binding もクリア
            DispatchQueue.main.async {
                self.drawing = PKDrawing()
            }
        }
        
        uiView.isUserInteractionEnabled = !isReadOnly
        updateInk(for: uiView)
    }
    
    private func updateInk(for canvasView: PKCanvasView) {
        let inkColor: UIColor
        if colorScheme == .dark {
            inkColor = UIColor(red: 0.92, green: 0.89, blue: 0.84, alpha: 1.0)
        } else {
            inkColor = UIColor(red: 0.3, green: 0.25, blue: 0.2, alpha: 1.0)
        }
        canvasView.tool = PKInkingTool(.pen, color: inkColor, width: 10.0)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: CanvasView
        var lastClearTrigger: Bool
        
        init(_ parent: CanvasView) {
            self.parent = parent
            self.lastClearTrigger = parent.clearTrigger
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            DispatchQueue.main.async {
                self.parent.drawing = canvasView.drawing
            }
        }
    }
}
