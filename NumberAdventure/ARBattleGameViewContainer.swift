import SwiftUI
import SceneKit
import ARKit
import CoreMotion

// MARK: - 数字ノードのメタデータ
struct TargetNodeData {
    let number: Int
    let position: SCNVector3
}

struct ARBattleGameViewContainer: UIViewRepresentable {
    let gameMode: BattleGameMode
    let ruleParam: Int
    let seed: UInt64
    let numbers: [Int]
    let isARMode: Bool
    
    // コールバック
    let onTargetTapped: (Int) -> Void
    var onShoot: (() -> Void)? = nil
    
    // 外部（ViewModel/View）からのリアクティブ通知
    @Binding var myLockTarget: Int?
    @Binding var opponentLockTarget: Int?
    @Binding var removedTargets: Set<Int>
    @Binding var matchedPair: (Int, Int)?
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView(frame: .zero)
        
        if isARMode && ARWorldTrackingConfiguration.isSupported {
            let arView = ARSCNView(frame: .zero)
            arView.delegate = context.coordinator
            arView.automaticallyUpdatesLighting = true
            
            let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
            arView.addGestureRecognizer(tapGesture)
            
            containerView.addSubview(arView)
            arView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                arView.topAnchor.constraint(equalTo: containerView.topAnchor),
                arView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                arView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                arView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
            ])
            
            context.coordinator.setupARSession(arView: arView)
        } else {
            let scnView = SCNView(frame: .zero)
            scnView.allowsCameraControl = false
            scnView.showsStatistics = false
            scnView.backgroundColor = .black
            
            let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
            scnView.addGestureRecognizer(tapGesture)
            
            let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
            scnView.addGestureRecognizer(panGesture)
            
            containerView.addSubview(scnView)
            scnView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                scnView.topAnchor.constraint(equalTo: containerView.topAnchor),
                scnView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                scnView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                scnView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
            ])
            
            context.coordinator.setup3DScene(scnView: scnView)
        }
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.updateLocks(my: myLockTarget, opponent: opponentLockTarget)
        context.coordinator.updateRemoved(removedTargets: removedTargets)
        if let pair = matchedPair {
            context.coordinator.triggerPairEffect(num1: pair.0, num2: pair.1)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - コーディネーター
    class Coordinator: NSObject, ARSCNViewDelegate {
        var parent: ARBattleGameViewContainer
        var scene: SCNScene!
        var cameraNode: SCNNode!
        weak var arView: ARSCNView?
        weak var scnView: SCNView?
        
        let motionManager = CMMotionManager()
        var cameraYaw: Float = 0.0
        var cameraPitch: Float = 0.0
        
        // ターゲットノード辞書 [数字: SCNNode]
        var targetNodes: [Int: SCNNode] = [:]
        
        // ハイライト用リングノード
        var myRingNode: SCNNode?
        var opponentRingNode: SCNNode?
        
        init(_ parent: ARBattleGameViewContainer) {
            self.parent = parent
            super.init()
        }
        
        deinit {
            motionManager.stopGyroUpdates()
        }
        
        // MARK: - AR Setup
        func setupARSession(arView: ARSCNView) {
            self.arView = arView
            self.scene = SCNScene()
            arView.scene = self.scene
            
            addLighting(to: scene.rootNode)
            
            let config = ARWorldTrackingConfiguration()
            config.planeDetection = []
            arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                guard let self = self else { return }
                self.spawnSyncedNumbers()
            }
        }
        
        // MARK: - 3D Scene Setup (シミュレータ / 非AR)
        func setup3DScene(scnView: SCNView) {
            self.scnView = scnView
            self.scene = SCNScene()
            scnView.scene = self.scene
            
            cameraNode = SCNNode()
            cameraNode.camera = SCNCamera()
            cameraNode.camera?.zNear = 0.1
            cameraNode.camera?.zFar = 100
            cameraNode.position = SCNVector3(0, 0, 0)
            scene.rootNode.addChildNode(cameraNode)
            
            addLighting(to: scene.rootNode)
            setupCosmicBackground()
            spawnSyncedNumbers()
            startGyroUpdates()
        }
        
        // MARK: - ライティング & 宇宙背景
        private func addLighting(to rootNode: SCNNode) {
            let ambient = SCNLight()
            ambient.type = .ambient
            ambient.intensity = 800
            ambient.color = UIColor(white: 0.8, alpha: 1.0)
            let ambientNode = SCNNode()
            ambientNode.light = ambient
            rootNode.addChildNode(ambientNode)
            
            let directional = SCNLight()
            directional.type = .directional
            directional.intensity = 1200
            directional.color = UIColor.white
            let directionalNode = SCNNode()
            directionalNode.light = directional
            directionalNode.position = SCNVector3(5, 10, 5)
            rootNode.addChildNode(directionalNode)
        }
        
        private func setupCosmicBackground() {
            let sphere = SCNSphere(radius: 20)
            sphere.segmentCount = 32
            sphere.firstMaterial?.isDoubleSided = true
            sphere.firstMaterial?.diffuse.contents = UIColor(red: 0.02, green: 0.03, blue: 0.1, alpha: 1.0)
            sphere.firstMaterial?.cullMode = .front
            let skyNode = SCNNode(geometry: sphere)
            scene.rootNode.addChildNode(skyNode)
            
            // 星くずパーティクル
            for _ in 0..<80 {
                let star = SCNSphere(radius: 0.05)
                star.firstMaterial?.diffuse.contents = UIColor.white
                star.firstMaterial?.emission.contents = UIColor.cyan
                let starNode = SCNNode(geometry: star)
                let theta = Float.random(in: 0...(Float.pi * 2))
                let phi = Float.random(in: -Float.pi/2...Float.pi/2)
                let r: Float = 15.0
                starNode.position = SCNVector3(
                    r * cos(phi) * sin(theta),
                    r * sin(phi),
                    r * cos(phi) * cos(theta)
                )
                scene.rootNode.addChildNode(starNode)
            }
        }
        
        // MARK: - シード値に基づく同一配置生成
        private func spawnSyncedNumbers() {
            targetNodes.removeAll()
            
            // 決定論的擬似乱数ジェネレータ
            var rng = SeededRandomNumberGenerator(seed: parent.seed)
            
            let count = parent.numbers.count
            let radiusMin: Float = 1.5
            let radiusMax: Float = 2.8
            
            for (index, num) in parent.numbers.enumerated() {
                // フィボナッチ球サンプリングで偏りなく球面上に分散
                let phi = acos(1.0 - 2.0 * (Float(index) + 0.5) / Float(count))
                let goldenRatio = (1.0 + sqrt(5.0)) / 2.0
                let theta = 2.0 * Float.pi * Float(index) / Float(goldenRatio)
                
                // 乱数シードから少し揺らぎを加える
                let jitterR = Float.random(in: radiusMin...radiusMax, using: &rng)
                let jitterPitch = Float.random(in: -0.2...0.2, using: &rng)
                let jitterYaw = Float.random(in: -0.2...0.2, using: &rng)
                
                let actualPhi = phi + jitterPitch
                let actualTheta = theta + jitterYaw
                
                let x = jitterR * sin(actualPhi) * sin(actualTheta)
                let y = jitterR * cos(actualPhi) * 0.7 // 上下の首振り負担を軽減するためやや水平気味に
                let z = -abs(jitterR * sin(actualPhi) * cos(actualTheta)) - 0.5 // 正面〜前方に多めに配置
                
                let node = createNumberNode(number: num, position: SCNVector3(x, y, z))
                scene.rootNode.addChildNode(node)
                targetNodes[num] = node
            }
        }
        
        // MARK: - 数字ノードの生成
        private func createNumberNode(number: Int, position: SCNVector3) -> SCNNode {
            let container = SCNNode()
            container.position = position
            container.name = "target_\(number)"
            
            // 1. 背景の惑星球体
            let sphere = SCNSphere(radius: 0.16)
            let material = SCNMaterial()
            let hue = CGFloat((number * 37) % 360) / 360.0
            let baseColor = UIColor(hue: hue, saturation: 0.75, brightness: 0.95, alpha: 0.9)
            material.diffuse.contents = baseColor
            material.emission.contents = baseColor.withAlphaComponent(0.3)
            material.specular.contents = UIColor.white
            material.shininess = 50
            sphere.materials = [material]
            
            let sphereNode = SCNNode(geometry: sphere)
            container.addChildNode(sphereNode)
            
            // 2. 数字テキスト
            let textGeo = SCNText(string: "\(number)", extrusionDepth: 0.02)
            textGeo.font = UIFont.systemFont(ofSize: 0.15, weight: .black)
            textGeo.alignmentMode = CATextLayerAlignmentMode.center.rawValue
            textGeo.firstMaterial?.diffuse.contents = UIColor.white
            textGeo.firstMaterial?.emission.contents = UIColor.white
            
            let textNode = SCNNode(geometry: textGeo)
            let (minVec, maxVec) = textGeo.boundingBox
            textNode.pivot = SCNMatrix4MakeTranslation(
                (maxVec.x - minVec.x) / 2.0 + minVec.x,
                (maxVec.y - minVec.y) / 2.0 + minVec.y,
                0
            )
            textNode.position = SCNVector3(0, 0, 0.17)
            container.addChildNode(textNode)
            
            // 常にカメラを向くビルボード制約
            let billboard = SCNBillboardConstraint()
            billboard.freeAxes = .all
            container.constraints = [billboard]
            
            // ふわふわ浮遊アニメーション
            let floatDistance = Float.random(in: 0.04...0.08)
            let floatDuration = Double.random(in: 2.0...3.5)
            let moveUp = SCNAction.moveBy(x: 0, y: CGFloat(floatDistance), z: 0, duration: floatDuration)
            moveUp.timingMode = .easeInEaseOut
            let moveDown = moveUp.reversed()
            let sequence = SCNAction.sequence([moveUp, moveDown])
            container.runAction(SCNAction.repeatForever(sequence))
            
            return container
        }
        
        // MARK: - ロックオンリングの更新
        func updateLocks(my: Int?, opponent: Int?) {
            // 自分のロック（オレンジ/イエローリング）
            updateRing(ringNode: &myRingNode, targetNum: my, color: .orange, offsetZ: 0.0)
            // 相手のロック（シアン/ブルーリング）
            updateRing(ringNode: &opponentRingNode, targetNum: opponent, color: .cyan, offsetZ: 0.02)
        }
        
        private func updateRing(ringNode: inout SCNNode?, targetNum: Int?, color: UIColor, offsetZ: Float) {
            guard let targetNum = targetNum, let targetNode = targetNodes[targetNum] else {
                ringNode?.removeFromParentNode()
                ringNode = nil
                return
            }
            
            if ringNode == nil {
                let torus = SCNTorus(ringRadius: 0.22, pipeRadius: 0.02)
                torus.firstMaterial?.diffuse.contents = color
                torus.firstMaterial?.emission.contents = color
                let node = SCNNode(geometry: torus)
                node.eulerAngles.x = .pi / 2
                ringNode = node
            }
            
            if ringNode?.parent != targetNode {
                ringNode?.removeFromParentNode()
                targetNode.addChildNode(ringNode!)
                ringNode?.position = SCNVector3(0, 0, offsetZ)
                
                // 回転アニメーション
                let rotate = SCNAction.rotateBy(x: 0, y: 0, z: CGFloat.pi * 2, duration: 2.0)
                ringNode?.runAction(SCNAction.repeatForever(rotate))
            }
        }
        
        // MARK: - 撃破された数字の消去エフェクト
        func updateRemoved(removedTargets: Set<Int>) {
            for num in removedTargets {
                if let node = targetNodes[num] {
                    targetNodes.removeValue(forKey: num)
                    
                    // 爆発・縮小エフェクト
                    let scaleUp = SCNAction.scale(to: 1.4, duration: 0.15)
                    let fade = SCNAction.fadeOut(duration: 0.2)
                    let scaleDown = SCNAction.scale(to: 0.01, duration: 0.2)
                    let group = SCNAction.group([scaleDown, fade])
                    let seq = SCNAction.sequence([scaleUp, group, SCNAction.removeFromParentNode()])
                    
                    node.runAction(seq)
                }
            }
        }
        
        // MARK: - ペア合体エフェクト（あわせて10）
        func triggerPairEffect(num1: Int, num2: Int) {
            guard let node1 = targetNodes[num1], let node2 = targetNodes[num2] else { return }
            
            // お互いの中心に向かって吸い寄せられる演出
            let midX = (node1.position.x + node2.position.x) / 2.0
            let midY = (node1.position.y + node2.position.y) / 2.0
            let midZ = (node1.position.z + node2.position.z) / 2.0
            let midPos = SCNVector3(midX, midY, midZ)
            
            let moveToMid1 = SCNAction.move(to: midPos, duration: 0.35)
            let moveToMid2 = SCNAction.move(to: midPos, duration: 0.35)
            moveToMid1.timingMode = .easeIn
            moveToMid2.timingMode = .easeIn
            
            node1.runAction(moveToMid1)
            node2.runAction(moveToMid2)
        }
        
        // MARK: - タップ判定＆発射 (画面のどこを押しても中央の照準に向けて発射)
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view else { return }
            
            // 1. 画面中央の照準（レティクル）位置
            let centerPoint = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
            let touchLocation = gesture.location(in: gesture.view)
            
            // 2. カメラの現在位置
            let currentCamera = arView?.pointOfView ?? cameraNode
            guard let cam = currentCamera else { return }
            let cameraPos = cam.presentation.position
            
            // 3. 画面中央（レティクル）を優先してHitTest
            var hitResults: [SCNHitTestResult] = []
            if let arView = arView {
                hitResults = arView.hitTest(centerPoint, options: [SCNHitTestOption.searchMode: SCNHitTestSearchMode.all.rawValue])
            } else if let scnView = scnView {
                hitResults = scnView.hitTest(centerPoint, options: [SCNHitTestOption.searchMode: SCNHitTestSearchMode.all.rawValue])
            }
            
            var targetNode: SCNNode? = nil
            var hitNumber: Int? = nil
            
            for hit in hitResults {
                var node: SCNNode? = hit.node
                while let current = node {
                    if let name = current.name, name.hasPrefix("target_"),
                       let numStr = name.split(separator: "_").last,
                       let number = Int(numStr) {
                        targetNode = current
                        hitNumber = number
                        break
                    }
                    node = current.parent
                }
                if targetNode != nil { break }
            }
            
            // 4. 中央に何もない場合、指で直接触った位置（タッチ位置）も判定（子ども向けの親切設計）
            if targetNode == nil {
                var directHits: [SCNHitTestResult] = []
                if let arView = arView {
                    directHits = arView.hitTest(touchLocation, options: [SCNHitTestOption.searchMode: SCNHitTestSearchMode.all.rawValue])
                } else if let scnView = scnView {
                    directHits = scnView.hitTest(touchLocation, options: [SCNHitTestOption.searchMode: SCNHitTestSearchMode.all.rawValue])
                }
                for hit in directHits {
                    var node: SCNNode? = hit.node
                    while let current = node {
                        if let name = current.name, name.hasPrefix("target_"),
                           let numStr = name.split(separator: "_").last,
                           let number = Int(numStr) {
                            targetNode = current
                            hitNumber = number
                            break
                        }
                        node = current.parent
                    }
                    if targetNode != nil { break }
                }
            }
            
            // 5. 弾の着弾地点を計算
            let hitPoint: SCNVector3
            if let target = targetNode {
                hitPoint = target.presentation.position
            } else {
                // レティクルの方向（カメラの正面2.5m先）
                let localFront = SCNVector3(0, 0, -2.5)
                hitPoint = cam.presentation.convertPosition(localFront, to: nil)
            }
            
            // 6. 魔法弾（レーザービーム）発射エフェクト！
            shootMagicBullet(from: cameraPos, to: hitPoint)
            
            // 発射コールバック（照準の縮小アニメーションや発射触覚用）
            parent.onShoot?()
            
            // 7. ヒットした数字があれば通知
            if let number = hitNumber {
                parent.onTargetTapped(number)
            }
        }
        
        // MARK: - 魔法弾発射エフェクト
        private func shootMagicBullet(from startPoint: SCNVector3, to endPoint: SCNVector3) {
            let colors: [UIColor] = [.systemYellow, .systemPink, .systemCyan, .systemGreen, .systemOrange]
            let bulletColor = colors.randomElement() ?? .systemYellow
            
            let bulletGeometry = SCNSphere(radius: 0.035)
            let bulletMaterial = SCNMaterial()
            bulletMaterial.diffuse.contents = UIColor.white
            bulletMaterial.emission.contents = bulletColor.withAlphaComponent(0.9)
            bulletGeometry.materials = [bulletMaterial]
            
            let bulletNode = SCNNode(geometry: bulletGeometry)
            bulletNode.position = startPoint
            
            let trail = SCNParticleSystem()
            trail.birthRate = 120
            trail.particleLifeSpan = 0.12
            trail.particleColor = bulletColor
            trail.particleSize = 0.02
            trail.speedFactor = 0.05
            trail.spreadingAngle = 15.0
            trail.emitterShape = SCNSphere(radius: 0.01)
            bulletNode.addParticleSystem(trail)
            
            scene.rootNode.addChildNode(bulletNode)
            
            let moveAction = SCNAction.move(to: endPoint, duration: 0.14)
            let removeAction = SCNAction.removeFromParentNode()
            bulletNode.runAction(SCNAction.sequence([moveAction, removeAction]))
        }
        
        // MARK: - シミュレータ・非AR時の視点パン操作
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard scnView != nil else { return }
            let translation = gesture.translation(in: gesture.view)
            let sensitivity: Float = 0.005
            
            cameraYaw -= Float(translation.x) * sensitivity
            cameraPitch -= Float(translation.y) * sensitivity
            cameraPitch = max(-Float.pi / 2.2, min(Float.pi / 2.2, cameraPitch))
            
            cameraNode.eulerAngles = SCNVector3(cameraPitch, cameraYaw, 0)
            gesture.setTranslation(.zero, in: gesture.view)
        }
        
        // MARK: - ジャイロ追従
        func startGyroUpdates() {
            guard motionManager.isDeviceMotionAvailable else { return }
            motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
                guard let self = self, let motion = motion, let cameraNode = self.cameraNode else { return }
                let pitch = Float(motion.attitude.pitch)
                let roll = Float(motion.attitude.roll)
                let yaw = Float(motion.attitude.yaw)
                cameraNode.eulerAngles = SCNVector3(-pitch, -yaw, -roll)
            }
        }
    }
}

// MARK: - 乱数シード生成器
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) {
        self.state = seed == 0 ? 0xdeadbeefcafe : seed
    }
    mutating func next() -> UInt64 {
        // xorshift64star
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 0x2545F4914F6CDD1D
    }
}
