import SwiftUI

struct StarryBackgroundView: View {
    @State private var starPositions: [CGPoint] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<starPositions.count, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(Double.random(in: 0.3...0.8)))
                        .frame(width: CGFloat.random(in: 1.5...3.5))
                        .position(starPositions[index])
                }
            }
            .onAppear {
                if starPositions.isEmpty {
                    var positions: [CGPoint] = []
                    for _ in 0..<60 {
                        let x = CGFloat.random(in: 0...geometry.size.width)
                        let y = CGFloat.random(in: 0...geometry.size.height)
                        positions.append(CGPoint(x: x, y: y))
                    }
                    starPositions = positions
                }
            }
        }
        .allowsHitTesting(false)
    }
}
