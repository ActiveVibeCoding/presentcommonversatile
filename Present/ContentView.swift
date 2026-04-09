import SwiftUI
import SceneKit

struct ContentView: View {
    @State private var carNode: SCNNode?
    @State private var cameraNode: SCNNode?
    
    // Physics & Controls
    @State private var isAccelerating = false
    @State private var isBraking = false
    @State private var steering: Float = 0 // Left -1.0, Right 1.0
    
    @State private var speed: Float = 0
    @State private var angle: Float = 0
    
    let maxSpeed: Float = 0.5
    let accelRate: Float = 0.015
    let friction: Float = 0.98

    var body: some View {
        ZStack {
            // 1. Full-screen Scene
            SceneView(
                scene: setupScene(),
                pointOfView: cameraNode,
                options: [.autoenablesDefaultLighting]
            )
            .ignoresSafeArea()

            // 2. HUD (Top Left)
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("VIBE_DRIVE v1.0")
                        Text("SPD: \(Int(speed * 200))").foregroundColor(.green)
                    }
                    .font(.system(.caption, design: .monospaced))
                    .padding(10)
                    .background(.black.opacity(0.5))
                    .cornerRadius(8)
                    Spacer()
                }
                .padding(.top, 50).padding(.leading, 20)
                Spacer()
            }

            // 3. Compact Controls (Bottom)
            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    // LEFT THUMB: Steering
                    HStack(spacing: 12) {
                        controlPad(label: "L", active: steering < 0) { steering = -1 } onEnd: { steering = 0 }
                        controlPad(label: "R", active: steering > 0) { steering = 1 } onEnd: { steering = 0 }
                    }
                    
                    Spacer()
                    
                    // RIGHT THUMB: Drive
                    HStack(spacing: 12) {
                        controlPad(label: "REV", color: .red, active: isBraking) { isBraking = true } onEnd: { isBraking = false }
                        controlPad(label: "GAS", color: .green, active: isAccelerating) { isAccelerating = true } onEnd: { isAccelerating = false }
                    }
                }
                .padding(.horizontal, 25)
                .padding(.bottom, 30)
            }
        }
        .onAppear { startLoop() }
    }

    // MARK: - Scene Construction
    func setupScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.black
        
        // Ground with neon grid
        let floor = SCNFloor()
        floor.firstMaterial?.diffuse.contents = generateGridImage()
        scene.rootNode.addChildNode(SCNNode(geometry: floor))
        
        // Detailed Car
        let car = createDetailedCar()
        scene.rootNode.addChildNode(car)
        self.carNode = car
        
        // Camera
        let camNode = SCNNode()
        camNode.camera = SCNCamera()
        camNode.camera?.zFar = 500
        camNode.position = SCNVector3(0, 4, -8)
        scene.rootNode.addChildNode(camNode)
        self.cameraNode = camNode
        
        return scene
    }

    func createDetailedCar() -> SCNNode {
        let root = SCNNode()
        
        // Body
        let body = SCNBox(width: 1.0, height: 0.4, length: 2.2, chamferRadius: 0.15)
        body.firstMaterial?.diffuse.contents = UIColor.systemBlue
        body.firstMaterial?.metalness.contents = 1.0
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position = SCNVector3(0, 0.3, 0)
        root.addChildNode(bodyNode)
        
        // Cockpit (Glass)
        let glass = SCNBox(width: 0.8, height: 0.4, length: 1.0, chamferRadius: 0.1)
        glass.firstMaterial?.diffuse.contents = UIColor.cyan.withAlphaComponent(0.5)
        let glassNode = SCNNode(geometry: glass)
        glassNode.position = SCNVector3(0, 0.6, 0.2)
        root.addChildNode(glassNode)
        
        // Spoiler
        let wing = SCNBox(width: 1.1, height: 0.05, length: 0.3, chamferRadius: 0)
        wing.firstMaterial?.diffuse.contents = UIColor.black
        let wingNode = SCNNode(geometry: wing)
        wingNode.position = SCNVector3(0, 0.7, -0.9)
        root.addChildNode(wingNode)
        
        // Headlights (Emmisive)
        let light = SCNBox(width: 0.3, height: 0.1, length: 0.1, chamferRadius: 0.05)
        light.firstMaterial?.emission.contents = UIColor.yellow
        let lNode = SCNNode(geometry: light); lNode.position = SCNVector3(0.3, 0.3, 1.1)
        let rNode = SCNNode(geometry: light); rNode.position = SCNVector3(-0.3, 0.3, 1.1)
        root.addChildNode(lNode); root.addChildNode(rNode)
        
        return root
    }

    // MARK: - Game Loop
    func startLoop() {
        Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { _ in
            guard let car = carNode, let cam = cameraNode else { return }
            
            // Physics logic
            if isAccelerating { speed = min(speed + accelRate, maxSpeed) }
            else if isBraking { speed = max(speed - accelRate, -0.15) }
            else { speed *= friction }
            
            angle += steering * (speed * 0.15)
            
            car.rotation = SCNVector4(0, 1, 0, angle)
            car.position.x += sin(angle) * speed
            car.position.z += cos(angle) * speed
            
            // Smooth Camera
            let idealPos = SCNVector3(car.position.x - sin(angle)*7, car.position.y + 3.5, car.position.z - cos(angle)*7)
            cam.position.x += (idealPos.x - cam.position.x) * 0.1
            cam.position.y += (idealPos.y - cam.position.y) * 0.1
            cam.position.z += (idealPos.z - cam.position.z) * 0.1
            cam.look(at: car.position)
        }
    }

    // MARK: - UI Components
    func controlPad(label: String, color: Color = .white, active: Bool, onStart: @escaping () -> Void, onEnd: @escaping () -> Void) -> some View {
        Text(label)
            .font(.system(.body, design: .monospaced)).bold()
            .frame(width: 60, height: 60)
            .background(active ? color.opacity(0.8) : .white.opacity(0.2))
            .foregroundColor(active ? .black : .white)
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(color.opacity(0.5), lineWidth: 2))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onStart() }
                    .onEnded { _ in onEnd() }
            )
    }
    
    func generateGridImage() -> UIImage {
        // Just a quick helper to make a grid texture
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 128, height: 128))
        return renderer.image { ctx in
            UIColor.darkGray.setStroke()
            ctx.stroke(CGRect(x: 0, y: 0, width: 128, height: 128), lineWidth: 2)
        }
    }
}
