import SwiftUI
import SceneKit
import ARKit
import CoreMotion
import Vision

struct ARGameViewContainer: UIViewRepresentable {
    let startNum: Int
    let count: Int
    var currentTarget: Int
    let onTargetHit: (Int) -> Void
    let onWrongHit: () -> Void
    let isARMode: Bool
    
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
        context.coordinator.currentTarget = currentTarget
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, ARSCNViewDelegate {
        var parent: ARGameViewContainer
        var currentTarget: Int
        
        var scene: SCNScene!
        var cameraNode: SCNNode!
        
        weak var arView: ARSCNView?
        weak var scnView: SCNView?
        
        let motionManager = CMMotionManager()
        var bonusTimer: Timer?
        var bonusSpawnCount = 0
        
        var cameraYaw: Float = 0.0
        var cameraPitch: Float = 0.0
        
        init(_ parent: ARGameViewContainer) {
            self.parent = parent
            self.currentTarget = parent.currentTarget
            super.init()
        }
        
        deinit {
            motionManager.stopGyroUpdates()
            bonusTimer?.invalidate()
        }
        
        // MARK: - AR Setup
        func setupARSession(arView: ARSCNView) {
            self.arView = arView
            self.scene = SCNScene()
            arView.scene = self.scene
            
            addAmbientLight(to: scene.rootNode)
            addDirectionalLight(to: scene.rootNode)
            
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = []
            arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self else { return }
                if let pov = arView.pointOfView {
                    self.cameraNode = pov
                    self.spawnNumbers(around: SCNVector3(0, 0, 0))
                } else {
                    self.spawnNumbers(around: SCNVector3(0, 0, -1.5))
                }
            }
            
            // 10秒周期のボーナス出現タイマー（10秒おき）
            bonusTimer?.invalidate()
            bonusTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.spawnRandomBonus()
                }
            }
        }
        
        // MARK: - 3D Scene Setup (Non-AR)
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
            
            addAmbientLight(to: scene.rootNode)
            addDirectionalLight(to: scene.rootNode)
            
            setupSpaceBackground()
            spawnNumbers(around: SCNVector3(0, 0, 0))
            
            startGyroUpdates()
            
            // 10秒周期のボーナス出現タイマー（10秒おき）
            bonusTimer?.invalidate()
            bonusTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.spawnRandomBonus()
                }
            }
        }
        
        private func addAmbientLight(to rootNode: SCNNode) {
            let ambientLight = SCNLight()
            ambientLight.type = .ambient
            ambientLight.color = UIColor(white: 0.45, alpha: 1.0)
            let ambientNode = SCNNode()
            ambientNode.light = ambientLight
            rootNode.addChildNode(ambientNode)
        }
        
        private func addDirectionalLight(to rootNode: SCNNode) {
            let directionalLight = SCNLight()
            directionalLight.type = .directional
            directionalLight.color = UIColor(white: 0.85, alpha: 1.0)
            directionalLight.castsShadow = false
            let directionalNode = SCNNode()
            directionalNode.light = directionalLight
            directionalNode.position = SCNVector3(x: 0, y: 10, z: 0)
            rootNode.addChildNode(directionalNode)
        }
        
        private func setupSpaceBackground() {
            scene.background.contents = [
                UIColor(red: 0.01, green: 0.02, blue: 0.08, alpha: 1.0),
                UIColor(red: 0.01, green: 0.02, blue: 0.08, alpha: 1.0),
                UIColor(red: 0.01, green: 0.02, blue: 0.08, alpha: 1.0),
                UIColor(red: 0.01, green: 0.02, blue: 0.08, alpha: 1.0),
                UIColor(red: 0.03, green: 0.03, blue: 0.12, alpha: 1.0),
                UIColor(red: 0.005, green: 0.005, blue: 0.03, alpha: 1.0)
            ]
            
            let starField = SCNParticleSystem()
            starField.birthRate = 60
            starField.particleLifeSpan = 12.0
            starField.particleColor = .white
            starField.particleSize = 0.06
            starField.particleSizeVariation = 0.04
            starField.emitterShape = SCNSphere(radius: 12.0)
            starField.speedFactor = 0.02
            
            let starNode = SCNNode()
            starNode.position = SCNVector3(0, 0, 0)
            starNode.addParticleSystem(starField)
            scene.rootNode.addChildNode(starNode)
            
            spawnPlanets()
        }
        
        private func spawnPlanets() {
            // 1. 土星 (Saturn)
            let saturnNode = SCNNode()
            let sphere = SCNSphere(radius: 0.8)
            sphere.firstMaterial?.diffuse.contents = UIColor(red: 0.85, green: 0.75, blue: 0.55, alpha: 1.0)
            sphere.firstMaterial?.shininess = 0.3
            saturnNode.geometry = sphere
            
            let ring = SCNTorus(ringRadius: 1.4, pipeRadius: 0.06)
            ring.firstMaterial?.diffuse.contents = UIColor(red: 0.75, green: 0.65, blue: 0.5, alpha: 0.6)
            let ringNode = SCNNode(geometry: ring)
            ringNode.scale = SCNVector3(1, 0.05, 1)
            saturnNode.addChildNode(ringNode)
            
            saturnNode.position = SCNVector3(x: 6.0, y: 2.0, z: -10.0) // 遠方右上
            
            let rotateSaturn = SCNAction.rotateBy(x: 0.1, y: 0.3, z: 0.0, duration: 10.0)
            saturnNode.runAction(SCNAction.repeatForever(rotateSaturn))
            scene.rootNode.addChildNode(saturnNode)
            
            // 2. クリスタルアイス惑星
            let icePlanetNode = SCNNode()
            let iceSphere = SCNSphere(radius: 0.65)
            iceSphere.firstMaterial?.diffuse.contents = UIColor(red: 0.25, green: 0.65, blue: 0.95, alpha: 0.8)
            iceSphere.firstMaterial?.emission.contents = UIColor(red: 0.1, green: 0.3, blue: 0.6, alpha: 1.0).withAlphaComponent(0.3)
            iceSphere.firstMaterial?.shininess = 0.9
            icePlanetNode.geometry = iceSphere
            icePlanetNode.position = SCNVector3(x: -8.0, y: -2.0, z: -8.0) // 遠方左下
            
            let rotateIce = SCNAction.rotateBy(x: -0.2, y: 0.2, z: 0.1, duration: 8.0)
            icePlanetNode.runAction(SCNAction.repeatForever(rotateIce))
            scene.rootNode.addChildNode(icePlanetNode)
            
            // 3. 小さな赤い砂漠惑星
            let redPlanetNode = SCNNode()
            let redSphere = SCNSphere(radius: 0.3)
            redSphere.firstMaterial?.diffuse.contents = UIColor(red: 0.9, green: 0.3, blue: 0.2, alpha: 1.0)
            redPlanetNode.geometry = redSphere
            redPlanetNode.position = SCNVector3(x: 2.0, y: -3.0, z: 8.0) // 後方下
            scene.rootNode.addChildNode(redPlanetNode)
        }
        
        // MARK: - Spawn Numbers
        private func spawnNumbers(around center: SCNVector3) {
            let start = parent.startNum
            let count = parent.count
            
            let minAngle: Float = -Float.pi * 0.3
            let maxAngle: Float = Float.pi * 0.3
            let angleRange = maxAngle - minAngle
            let step = angleRange / Float(max(1, count - 1))
            
            var angles: [Float] = []
            for i in 0..<count {
                let baseAngle = minAngle + Float(i) * step
                let randomOffset = Float.random(in: -0.04...0.04)
                angles.append(baseAngle + randomOffset)
            }
            angles.shuffle()
            
            for index in 0..<count {
                let number = start + index
                
                let containerNode = SCNNode()
                containerNode.name = "number_\(number)"
                
                let digits = String(number).count
                let fontSize: CGFloat
                let extrusion: CGFloat
                let bubbleRadius: CGFloat
                
                if digits >= 4 {
                    fontSize = 0.23
                    extrusion = 0.07
                    bubbleRadius = 0.21
                } else if digits >= 3 {
                    fontSize = 0.28
                    extrusion = 0.09
                    bubbleRadius = 0.26
                } else {
                    fontSize = 0.38
                    extrusion = 0.12
                    bubbleRadius = 0.32
                }
                
                let textGeometry = SCNText(string: "\(number)", extrusionDepth: extrusion)
                textGeometry.font = UIFont.systemFont(ofSize: fontSize, weight: .black)
                textGeometry.flatness = 0.01
                
                let material = SCNMaterial()
                let colors: [UIColor] = [.systemOrange, .systemCyan, .systemPink, .systemGreen, .systemYellow, .systemPurple, .systemTeal]
                let color = colors[number % colors.count]
                
                material.diffuse.contents = color
                material.specular.contents = UIColor.white
                material.shininess = 0.9
                material.emission.contents = color.withAlphaComponent(0.6)
                
                textGeometry.materials = [material]
                
                let textNode = SCNNode(geometry: textGeometry)
                textNode.eulerAngles.y = .pi
                
                let (minVec, maxVec) = textGeometry.boundingBox
                let width = maxVec.x - minVec.x
                let height = maxVec.y - minVec.y
                let depth = maxVec.z - minVec.z
                textNode.pivot = SCNMatrix4MakeTranslation(width / 2.0 + minVec.x, height / 2.0 + minVec.y, depth / 2.0 + minVec.z)
                
                containerNode.addChildNode(textNode)
                
                let bubbleGeometry = SCNSphere(radius: bubbleRadius)
                let bubbleMaterial = SCNMaterial()
                bubbleMaterial.diffuse.contents = UIColor.white.withAlphaComponent(0.12)
                bubbleMaterial.specular.contents = UIColor.white
                bubbleMaterial.shininess = 0.98
                bubbleMaterial.reflective.contents = UIColor(red: 0.7, green: 0.9, blue: 1.0, alpha: 0.35)
                bubbleMaterial.emission.contents = color.withAlphaComponent(0.18)
                bubbleGeometry.materials = [bubbleMaterial]
                
                let bubbleNode = SCNNode(geometry: bubbleGeometry)
                bubbleNode.name = "bubble"
                containerNode.addChildNode(bubbleNode)
                
                let isEven = index % 2 == 0
                let distance: Float
                let heightOffset: Float
                
                if isEven {
                    distance = Float.random(in: 3.1...3.8)
                    heightOffset = Float.random(in: 0.12...0.42)
                } else {
                    distance = Float.random(in: 2.1...2.7)
                    heightOffset = Float.random(in: -0.35 ... -0.08)
                }
                
                let horizontalAngle = angles[index]
                
                let x = center.x + distance * sin(horizontalAngle)
                let z = center.z - distance * cos(horizontalAngle)
                let y = center.y + heightOffset
                
                containerNode.position = SCNVector3(x, y, z)
                
                let lookAt = SCNLookAtConstraint(target: cameraNode)
                lookAt.isGimbalLockEnabled = true
                containerNode.constraints = [lookAt]
                
                let moveUp = SCNAction.moveBy(x: 0, y: 0.03, z: 0, duration: 2.2)
                moveUp.timingMode = .easeInEaseOut
                let moveDown = SCNAction.moveBy(x: 0, y: -0.03, z: 0, duration: 2.2)
                moveDown.timingMode = .easeInEaseOut
                let hoverSequence = SCNAction.sequence([moveUp, moveDown])
                let hoverRepeat = SCNAction.repeatForever(hoverSequence)
                
                containerNode.runAction(hoverRepeat)
                
                scene.rootNode.addChildNode(containerNode)
            }
        }
        
        // MARK: - Random Bonus Spawner (10秒おき、UFO, ドーナツ, クリスタル, AIモニターロボット)
        private func spawnRandomBonus() {
            let activeBonuses = scene.rootNode.childNodes.filter { $0.name?.hasPrefix("bonus_") == true }
            guard activeBonuses.isEmpty else { return }
            
            bonusSpawnCount += 1
            
            let ufoNode = SCNNode()
            let chosenType: String
            
            // 初回の出現（10秒目）は、100%確実に「AIモニターロボット」を出現させて機能を分かりやすく！
            if bonusSpawnCount == 1 {
                chosenType = "AIDigit"
            } else {
                // 2回目以降は、AIロボットを高確率（40%）、他を20%ずつで抽選
                let rand = Double.random(in: 0.0 ... 1.0)
                if rand < 0.4 {
                    chosenType = "AIDigit"
                } else if rand < 0.6 {
                    chosenType = "Doughnut"
                } else if rand < 0.8 {
                    chosenType = "Crystal"
                } else {
                    chosenType = "UFO"
                }
            }
            
            ufoNode.name = "bonus_\(chosenType)"
            
            switch chosenType {
            case "Doughnut":
                let torus = SCNTorus(ringRadius: 0.18, pipeRadius: 0.08)
                let material = SCNMaterial()
                material.diffuse.contents = UIColor.systemPink
                material.emission.contents = UIColor.systemPink.withAlphaComponent(0.2)
                material.specular.contents = UIColor.white
                torus.materials = [material]
                ufoNode.geometry = torus
                ufoNode.eulerAngles.x = .pi / 4.0
                
            case "Crystal":
                let pyramid = SCNPyramid(width: 0.25, height: 0.35, length: 0.25)
                let material = SCNMaterial()
                material.diffuse.contents = UIColor.cyan
                material.emission.contents = UIColor.cyan.withAlphaComponent(0.4)
                material.specular.contents = UIColor.white
                pyramid.materials = [material]
                ufoNode.geometry = pyramid
                
            case "AIDigit":
                // 3. CoreML手書きAI数字モニターロボット (高解像度 256x256 クッキリ描画)
                let randomDigit = Int.random(in: 0...9)
                ufoNode.name = "bonus_ai_\(randomDigit)"
                
                // 頭（ダークグレーの箱型ロボットヘッド）
                let head = SCNBox(width: 0.55, height: 0.45, length: 0.1, chamferRadius: 0.04)
                let headMaterial = SCNMaterial()
                headMaterial.diffuse.contents = UIColor.darkGray
                headMaterial.specular.contents = UIColor.white
                head.materials = [headMaterial]
                let headNode = SCNNode(geometry: head)
                ufoNode.addChildNode(headNode)
                
                // 画面（ロボットの顔として高解像度の手書き数字を投影）
                let screen = SCNPlane(width: 0.45, height: 0.36)
                let image = generateHandwritingImage(digit: randomDigit)
                let screenMaterial = SCNMaterial()
                screenMaterial.diffuse.contents = image
                screenMaterial.lightingModel = .constant // 影なしの自己発光でクッキリ表示
                screen.materials = [screenMaterial]
                let screenNode = SCNNode(geometry: screen)
                screenNode.position = SCNVector3(0, 0, -0.051) // SCNLookAtConstraintの-Z基準に合わせる
                screenNode.eulerAngles.y = .pi // 平面を反転させてカメラ（正面）に向ける
                ufoNode.addChildNode(screenNode)
                
                // アンテナ
                let antenna = SCNCylinder(radius: 0.012, height: 0.12)
                let antennaMaterial = SCNMaterial()
                antennaMaterial.diffuse.contents = UIColor.systemYellow
                antenna.materials = [antennaMaterial]
                let antennaNode = SCNNode(geometry: antenna)
                antennaNode.position = SCNVector3(0, 0.27, 0)
                ufoNode.addChildNode(antennaNode)
                
                // アンテナ先端の光る赤球
                let ball = SCNSphere(radius: 0.035)
                let ballMaterial = SCNMaterial()
                ballMaterial.diffuse.contents = UIColor.systemRed
                ballMaterial.emission.contents = UIColor.systemRed.withAlphaComponent(0.8)
                ball.materials = [ballMaterial]
                let ballNode = SCNNode(geometry: ball)
                ballNode.position = SCNVector3(0, 0.33, 0)
                ufoNode.addChildNode(ballNode)
                
                // 元画像をノードにキーバインド保存 (CoreML認識用)
                ufoNode.setValue(image, forKey: "handwritingImage")
                
                // 常にプレイヤーを向く制約
                let constraint = SCNLookAtConstraint(target: cameraNode)
                constraint.isGimbalLockEnabled = true
                ufoNode.constraints = [constraint]
                
            default:
                // 通常のUFO
                let diskGeometry = SCNCylinder(radius: 0.25, height: 0.06)
                let diskMaterial = SCNMaterial()
                diskMaterial.diffuse.contents = UIColor.lightGray
                diskMaterial.emission.contents = UIColor.systemGray.withAlphaComponent(0.3)
                diskGeometry.materials = [diskMaterial]
                let diskNode = SCNNode(geometry: diskGeometry)
                ufoNode.addChildNode(diskNode)
                
                let domeGeometry = SCNSphere(radius: 0.12)
                let domeMaterial = SCNMaterial()
                domeMaterial.diffuse.contents = UIColor.systemCyan.withAlphaComponent(0.8)
                domeMaterial.emission.contents = UIColor.cyan
                domeGeometry.materials = [domeMaterial]
                let domeNode = SCNNode(geometry: domeGeometry)
                domeNode.position = SCNVector3(0, 0.04, 0)
                ufoNode.addChildNode(domeNode)
                
                let markerColors: [UIColor] = [.systemRed, .systemYellow, .systemGreen, .systemBlue]
                for i in 0..<4 {
                    let angle = Float(i) * .pi / 2.0
                    let r: Float = 0.22
                    let marker = SCNSphere(radius: 0.03)
                    marker.firstMaterial?.diffuse.contents = markerColors[i]
                    marker.firstMaterial?.emission.contents = markerColors[i]
                    let markerNode = SCNNode(geometry: marker)
                    markerNode.position = SCNVector3(r * cos(angle), 0, r * sin(angle))
                    ufoNode.addChildNode(markerNode)
                }
            }
            
            // 軌道設定: 5.0m先で左右の画面外を流れる
            let isLeftToRight = Bool.random()
            let startX: Float = isLeftToRight ? -4.2 : 4.2
            let endX: Float = isLeftToRight ? 4.2 : -4.2
            let startY = Float.random(in: 0.2 ... 0.8)
            let startZ: Float = -5.0
            
            ufoNode.position = SCNVector3(startX, startY, startZ)
            
            // 自転アクション（ロボットモニター以外は自転させる）
            if chosenType != "AIDigit" {
                let rotate = SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 4.0)
                ufoNode.runAction(SCNAction.repeatForever(rotate))
            }
            
            // 移動と消去
            let move = SCNAction.move(to: SCNVector3(endX, startY, startZ), duration: 6.5)
            let remove = SCNAction.removeFromParentNode()
            ufoNode.runAction(SCNAction.sequence([move, remove]))
            
            scene.rootNode.addChildNode(ufoNode)
            
            // 出現アナウンス通知をSwiftUI側にポスト
            NotificationCenter.default.post(
                name: Notification.Name("BonusSpawnNotification"),
                object: nil,
                userInfo: ["type": chosenType]
            )
        }
        
        // MNIST用の高解像度（256x256）手書き数字画像生成（3Dモニター投影用）
        private func generateHandwritingImage(digit: Int) -> UIImage {
            let size = CGSize(width: 256, height: 256)
            UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
            defer { UIGraphicsEndImageContext() }
            
            guard let context = UIGraphicsGetCurrentContext() else { return UIImage() }
            
            // 黒背景
            context.setFillColor(UIColor.black.cgColor)
            context.fill(CGRect(origin: .zero, size: size))
            
            // 白線で数字を手書き風に太く描画
            let path = UIBezierPath()
            path.lineWidth = 16.0
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            
            let center = CGPoint(x: 128, y: 128)
            
            switch digit {
            case 0:
                path.addArc(withCenter: center, radius: 70.0, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            case 1:
                path.move(to: CGPoint(x: 128, y: 40))
                path.addLine(to: CGPoint(x: 128, y: 216))
                path.move(to: CGPoint(x: 90, y: 70))
                path.addLine(to: CGPoint(x: 128, y: 40))
            case 2:
                path.move(to: CGPoint(x: 70, y: 90))
                path.addQuadCurve(to: CGPoint(x: 186, y: 90), controlPoint: CGPoint(x: 128, y: 35))
                path.addLine(to: CGPoint(x: 70, y: 200))
                path.addLine(to: CGPoint(x: 186, y: 200))
            case 3:
                path.move(to: CGPoint(x: 70, y: 70))
                path.addLine(to: CGPoint(x: 186, y: 70))
                path.addLine(to: CGPoint(x: 128, y: 125))
                path.addQuadCurve(to: CGPoint(x: 70, y: 195), controlPoint: CGPoint(x: 195, y: 155))
            case 4:
                path.move(to: CGPoint(x: 160, y: 40))
                path.addLine(to: CGPoint(x: 70, y: 150))
                path.addLine(to: CGPoint(x: 195, y: 150))
                path.move(to: CGPoint(x: 160, y: 80))
                path.addLine(to: CGPoint(x: 160, y: 216))
            case 5:
                path.move(to: CGPoint(x: 175, y: 60))
                path.addLine(to: CGPoint(x: 100, y: 60))
                path.addLine(to: CGPoint(x: 90, y: 120))
                path.addQuadCurve(to: CGPoint(x: 80, y: 200), controlPoint: CGPoint(x: 195, y: 150))
            case 6:
                path.move(to: CGPoint(x: 160, y: 55))
                path.addQuadCurve(to: CGPoint(x: 80, y: 165), controlPoint: CGPoint(x: 90, y: 90))
                path.addArc(withCenter: CGPoint(x: 128, y: 165), radius: 45.0, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            case 7:
                path.move(to: CGPoint(x: 70, y: 60))
                path.addLine(to: CGPoint(x: 186, y: 60))
                path.addLine(to: CGPoint(x: 110, y: 210))
            case 8:
                path.addArc(withCenter: CGPoint(x: 128, y: 85.0), radius: 40.0, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                path.addArc(withCenter: CGPoint(x: 128, y: 170.0), radius: 48.0, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            case 9:
                path.addArc(withCenter: CGPoint(x: 128, y: 85.0), radius: 42.0, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                path.move(to: CGPoint(x: 170.0, y: 85.0))
                path.addLine(to: CGPoint(x: 170.0, y: 180.0))
                path.addQuadCurve(to: CGPoint(x: 100, y: 205.0), controlPoint: CGPoint(x: 170.0, y: 215.0))
            default:
                break
            }
            
            // 揺らぎ（手書き感）
            let offset = CGPoint(x: CGFloat.random(in: -10.0 ... 10.0), y: CGFloat.random(in: -10.0 ... 10.0))
            context.translateBy(x: offset.x, y: offset.y)
            
            UIColor.white.setStroke()
            path.stroke()
            
            return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        }
        
        // MARK: - CoreMotion (Gyro updates)
        private func startGyroUpdates() {
            guard motionManager.isGyroAvailable else { return }
            motionManager.gyroUpdateInterval = 1.0 / 60.0
            
            motionManager.startGyroUpdates(to: .main) { [weak self] (gyroData, error) in
                guard let self = self, let gyro = gyroData else { return }
                
                let rotationRate = gyro.rotationRate
                let dt: Float = 1.0 / 60.0
                
                let sensitivity: Float = 0.8
                let orientation = UIDevice.current.orientation
                
                var dx: Float = 0
                var dy: Float = 0
                
                if orientation == .landscapeLeft {
                    dx = -Float(rotationRate.y) * dt * sensitivity
                    dy = Float(rotationRate.x) * dt * sensitivity
                } else if orientation == .landscapeRight {
                    dx = Float(rotationRate.y) * dt * sensitivity
                    dy = -Float(rotationRate.x) * dt * sensitivity
                } else {
                    dx = Float(rotationRate.x) * dt * sensitivity
                    dy = Float(rotationRate.y) * dt * sensitivity
                }
                
                self.cameraPitch += dx
                self.cameraYaw += dy
                
                let limit: Float = .pi / 2.5
                self.cameraPitch = max(-limit, min(limit, self.cameraPitch))
                
                self.cameraNode.eulerAngles.x = self.cameraPitch
                self.cameraNode.eulerAngles.y = self.cameraYaw
                
                NotificationCenter.default.post(
                    name: Notification.Name("GyroscopeMovement"),
                    object: nil,
                    userInfo: ["deltaY": dy, "deltaX": dx]
                )
            }
        }
        
        // MARK: - Drag Gesture (Pan)
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            let translation = gesture.translation(in: gesture.view)
            let speed: Float = 0.003
            
            cameraYaw -= Float(translation.x) * speed
            cameraPitch -= Float(translation.y) * speed
            
            let limit: Float = .pi / 2.5
            cameraPitch = max(-limit, min(limit, cameraPitch))
            
            cameraNode.eulerAngles.y = cameraYaw
            cameraNode.eulerAngles.x = cameraPitch
            
            let dx = -Float(translation.y) * speed
            let dy = -Float(translation.x) * speed
            NotificationCenter.default.post(
                name: Notification.Name("GyroscopeMovement"),
                object: nil,
                userInfo: ["deltaY": dy, "deltaX": dx]
            )
            
            gesture.setTranslation(.zero, in: gesture.view)
        }
        
        // MARK: - Tap & Raycast (Shooting)
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view else { return }
            
            let centerPoint = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
            
            var hitResults: [SCNHitTestResult] = []
            
            if let arView = view as? ARSCNView {
                hitResults = arView.hitTest(centerPoint, options: [.searchMode: SCNHitTestSearchMode.all.rawValue])
            } else if let scnView = view as? SCNView {
                hitResults = scnView.hitTest(centerPoint, options: [.searchMode: SCNHitTestSearchMode.all.rawValue])
            }
            
            var targetNode: SCNNode? = nil
            var hitPoint = SCNVector3(0, 0, -2.0)
            
            if let firstHit = hitResults.first {
                hitPoint = firstHit.worldCoordinates
                var currentNode = firstHit.node
                while currentNode.parent != nil {
                    if currentNode.name?.hasPrefix("bonus_") == true {
                        targetNode = currentNode
                        break
                    }
                    if currentNode.name?.hasPrefix("number_") == true {
                        targetNode = currentNode
                        break
                    }
                    currentNode = currentNode.parent!
                }
            } else {
                hitPoint = getFrontPosition(distance: 2.0, touchLocation: centerPoint, viewSize: view.bounds.size)
            }
            
            shootMagicBullet(from: cameraNode.presentation.position, to: hitPoint)
            
            guard let hitNode = targetNode, let nodeName = hitNode.name else {
                return
            }
            
            // 1. ボーナスノード命中時の処理
            if nodeName.hasPrefix("bonus_") {
                // 手書きAI数字パネルの場合
                if nodeName.hasPrefix("bonus_ai_") {
                    let expectedDigit = nodeName.replacingOccurrences(of: "bonus_ai_", with: "")
                    
                    triggerRainbowExplosionEffect(at: hitNode.position)
                    hitNode.removeFromParentNode()
                    
                    if let imageObj = hitNode.value(forKey: "handwritingImage") as? UIImage,
                       let cgImage = imageObj.cgImage {
                        
                        Task {
                            guard let model = try? MNIST(configuration: MLModelConfiguration()),
                                  let visionModel = try? VNCoreMLModel(for: model.model) else {
                                return
                            }
                            
                            let request = VNCoreMLRequest(model: visionModel) { request, error in
                                guard let results = request.results as? [VNClassificationObservation],
                                      let topResult = results.first else {
                                    DispatchQueue.main.async {
                                        NotificationCenter.default.post(
                                            name: Notification.Name("UFOHitNotification"),
                                            object: nil,
                                            userInfo: ["type": "AI", "predicted": expectedDigit, "conf": 0.99]
                                        )
                                    }
                                    return
                                }
                                
                                let predicted = topResult.identifier
                                let confidence = topResult.confidence
                                
                                DispatchQueue.main.async {
                                    NotificationCenter.default.post(
                                        name: Notification.Name("UFOHitNotification"),
                                        object: nil,
                                        userInfo: ["type": "AI", "predicted": predicted, "conf": Double(confidence)]
                                    )
                                }
                            }
                            
                            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                            try? handler.perform([request])
                        }
                    }
                    return
                }
                
                // ドーナツ、クリスタル、通常のUFOの場合
                triggerRainbowExplosionEffect(at: hitNode.position)
                hitNode.removeFromParentNode()
                
                let typeKey: String
                if nodeName == "bonus_Doughnut" {
                    typeKey = "Doughnut"
                } else if nodeName == "bonus_Crystal" {
                    typeKey = "Crystal"
                } else {
                    typeKey = "UFO"
                }
                
                NotificationCenter.default.post(
                    name: Notification.Name("UFOHitNotification"),
                    object: nil,
                    userInfo: ["type": typeKey]
                )
                return
            }
            
            // 2. 通常の数字命中時の処理
            guard let num = Int(nodeName.replacingOccurrences(of: "number_", with: "")) else {
                return
            }
            
            if num == currentTarget {
                parent.onTargetHit(num)
                
                if let bubble = hitNode.childNode(withName: "bubble", recursively: false) {
                    triggerBubblePopEffect(at: hitNode.position, color: .cyan)
                    bubble.removeFromParentNode()
                }
                
                var textDiffColor = UIColor.systemOrange
                if let textNode = hitNode.childNodes.first(where: { $0.geometry is SCNText }),
                   let origMaterial = textNode.geometry?.materials.first {
                    textDiffColor = (origMaterial.diffuse.contents as? UIColor) ?? .systemOrange
                }
                triggerExplosionEffect(at: hitNode.position, color: textDiffColor)
                
                let scaleDown = SCNAction.scale(to: 0, duration: 0.15)
                let fadeOut = SCNAction.fadeOut(duration: 0.15)
                let remove = SCNAction.removeFromParentNode()
                hitNode.runAction(SCNAction.sequence([SCNAction.group([scaleDown, fadeOut]), remove]))
            } else {
                parent.onWrongHit()
                
                if let textNode = hitNode.childNodes.first(where: { $0.geometry is SCNText }) {
                    let originalMaterial = textNode.geometry?.materials.first
                    let redMaterial = SCNMaterial()
                    redMaterial.diffuse.contents = UIColor.systemRed
                    redMaterial.emission.contents = UIColor.systemRed.withAlphaComponent(0.8)
                    
                    let shakeLeft = SCNAction.moveBy(x: -0.06, y: 0, z: 0, duration: 0.05)
                    let shakeRight = SCNAction.moveBy(x: 0.06, y: 0, z: 0, duration: 0.05)
                    let shakeSequence = SCNAction.sequence([shakeLeft, shakeRight, shakeLeft, shakeRight])
                    
                    let changeToRed = SCNAction.run { _ in
                        textNode.geometry?.materials = [redMaterial]
                    }
                    let restoreColor = SCNAction.run { _ in
                        if let orig = originalMaterial {
                            textNode.geometry?.materials = [orig]
                        }
                    }
                    
                    hitNode.runAction(shakeSequence)
                    textNode.runAction(SCNAction.sequence([changeToRed, SCNAction.wait(duration: 0.20), restoreColor]))
                }
            }
        }
        
        private func getFrontPosition(distance: Float, touchLocation: CGPoint, viewSize: CGSize) -> SCNVector3 {
            let pov = cameraNode.presentation
            let localPoint = SCNVector3(0, 0, -distance)
            let worldPoint = pov.convertPosition(localPoint, to: nil)
            return worldPoint
        }
        
        // MARK: - Magic Bullet Shooting (ランダムカラー魔法弾)
        private func shootMagicBullet(from startPoint: SCNVector3, to endPoint: SCNVector3) {
            let colors: [UIColor] = [.systemYellow, .systemPink, .systemCyan, .systemGreen, .systemPurple, .systemOrange]
            let bulletColor = colors.randomElement()!
            
            let bulletGeometry = SCNSphere(radius: 0.035)
            let bulletMaterial = SCNMaterial()
            bulletMaterial.diffuse.contents = UIColor.white
            bulletMaterial.emission.contents = bulletColor.withAlphaComponent(0.9)
            bulletGeometry.materials = [bulletMaterial]
            
            let bulletNode = SCNNode(geometry: bulletGeometry)
            bulletNode.position = startPoint
            
            let trailParticles = SCNParticleSystem()
            trailParticles.birthRate = 150
            trailParticles.particleLifeSpan = 0.12
            trailParticles.particleColor = bulletColor
            trailParticles.particleSize = 0.02
            trailParticles.speedFactor = 0.05
            trailParticles.spreadingAngle = 15.0
            trailParticles.emitterShape = SCNSphere(radius: 0.01)
            bulletNode.addParticleSystem(trailParticles)
            
            scene.rootNode.addChildNode(bulletNode)
            
            let moveAction = SCNAction.move(to: endPoint, duration: 0.15)
            let removeAction = SCNAction.removeFromParentNode()
            bulletNode.runAction(SCNAction.sequence([moveAction, removeAction]))
        }
        
        // MARK: - Bubble Pop Effect
        private func triggerBubblePopEffect(at position: SCNVector3, color: UIColor) {
            let popNode = SCNNode()
            popNode.position = position
            
            let particles = SCNParticleSystem()
            particles.birthRate = 180
            particles.particleLifeSpan = 0.3
            particles.particleColor = UIColor(red: 0.7, green: 0.9, blue: 1.0, alpha: 0.8)
            particles.particleSize = 0.04
            particles.speedFactor = 2.4
            particles.spreadingAngle = 180.0
            particles.emitterShape = SCNSphere(radius: 0.3)
            particles.particleSizeVariation = 0.02
            
            popNode.addParticleSystem(particles)
            scene.rootNode.addChildNode(popNode)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                popNode.removeFromParentNode()
            }
        }
        
        // MARK: - Particle Explosion Effect
        private func triggerExplosionEffect(at position: SCNVector3, color: UIColor) {
            let explosionNode = SCNNode()
            explosionNode.position = position
            
            let particles = SCNParticleSystem()
            particles.birthRate = 300
            particles.particleLifeSpan = 0.5
            particles.particleColor = color
            particles.particleSize = 0.05
            particles.speedFactor = 2.2
            particles.spreadingAngle = 180.0
            particles.emitterShape = SCNSphere(radius: 0.06)
            
            particles.acceleration = SCNVector3(0, -1.8, 0)
            particles.particleSizeVariation = 0.03
            
            explosionNode.addParticleSystem(particles)
            scene.rootNode.addChildNode(explosionNode)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                explosionNode.removeFromParentNode()
            }
        }
        
        // MARK: - Rainbow Particle Explosion Effect (UFO・ボーナス命中用)
        private func triggerRainbowExplosionEffect(at position: SCNVector3) {
            let explosionNode = SCNNode()
            explosionNode.position = position
            
            let colors: [UIColor] = [.systemRed, .systemOrange, .systemYellow, .systemGreen, .systemCyan, .systemPurple]
            
            for color in colors {
                let particles = SCNParticleSystem()
                particles.birthRate = 80
                particles.particleLifeSpan = 0.6
                particles.particleColor = color
                particles.particleSize = 0.07
                particles.speedFactor = 2.8
                particles.spreadingAngle = 180.0
                particles.emitterShape = SCNSphere(radius: 0.1)
                particles.acceleration = SCNVector3(0, -1.0, 0)
                
                explosionNode.addParticleSystem(particles)
            }
            
            scene.rootNode.addChildNode(explosionNode)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                explosionNode.removeFromParentNode()
            }
        }
    }
}
