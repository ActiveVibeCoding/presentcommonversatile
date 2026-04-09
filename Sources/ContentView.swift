import SwiftUI
import SceneKit

struct ContentView: View {
    @State private var carNode: SCNNode?
    @State private var cameraNode: SCNNode?
    
    @State private var isAccelerating = false
    @State private var isBraking = false
    @State private var steering: Float = 0
    @State private var speed: Float = 0
    @State private var angle: Float = 0
    
    let maxSpeed: Float = 0.5
    let accelRate: Float = 0.015
    let friction: Float = 0.98

    var body: some View {
        ZStack {
            // The 3D View
            SceneView(
                scene: setupScene(),
                pointOfView: cameraNode,
                options: [.autoenablesDefaultLighting]
            )
            .ignoresSafeArea()

            // HUD Overlay
            VStack {
                HStack {
                    VStack(alignment: .leading) {
                        Text("VIBE_DRIVE_PRO")
                        Text("SPD: \(Int(speed * 200))").foregroundColor(.green)
                    }
                    .font(.system(.caption, design: .monospaced))
                    .padding(10)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                    Spacer()
                }
                .padding(.top, 50).padding(.leading, 20)
                Spacer()
            }

            // Controls
            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    HStack(spacing: 15) {
                        controlPad(label: "L", active: steering < 0) { steering = -1 } onEnd: { steering = 0 }
                        controlPad(label: "R", active: steering > 0) { steering = 1 } onEnd: { steering = 0 }
                    }
                    Spacer()
                    HStack(spacing: 15) {
                        controlPad(label: "REV", color: .red, active: isBraking) { isBraking = true } onEnd: { isBraking = false }
                        controlPad(label: "GAS", color: .green, active: isAccelerating) { isAccelerating = true } onEnd: { isAccelerating = false }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
            }
        }
        .onAppear { startEngine() }
    }

    func setupScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.black
        
        // Manual Lighting Setup (Fixes the black screen)
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 400
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)

        let sunLight = SCNLight()
        sunLight.type = .directional
        sunLight.intensity = 1000
        let sunNode = SCNNode()
        sunNode.light = sunLight
        sunNode.position = SCNVector3(x: 5, y: 10, z: 5)
        sunNode.eulerAngles = SCNVector3(-Float.pi/4, Float.pi/4, 0)
        scene.rootNode.addChildNode(sunNode)
        
        // Ground
        let floor = SCNFloor()
        floor.firstMaterial?.diffuse.contents = generateGrid()
        let floorNode = SCNNode(geometry: floor)
        scene.rootNode.addChildNode(floorNode)
        
        // Car
        let car = createCar()
        scene.rootNode.addChildNode(car)
        self.carNode = car
        
        // Camera
        let cam = SCNCamera()
        cam.zFar = 1000
        let camNode = SCNNode()
        camNode.camera = cam
        camNode.name = "mainCamera"
        camNode.position = SCNVector3(0, 4, -8)
        scene.rootNode.addChildNode(camNode)
        self.cameraNode = camNode
        
        return scene
    }

    func createCar() -> SCNNode {
        let root = SCNNode()
        
        let body = SCNBox(width: 1.2, height: 0.5, length: 2.5, chamferRadius: 0.2)
        body.firstMaterial?.diffuse.contents = UIColor.systemBlue
        body.firstMaterial?.lightingModel = .physicallyBased
        body.firstMaterial?.metalness.contents = 0.8
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position = SCNVector3(0, 0.4, 0)
        root.addChildNode(bodyNode)
        
        let glass = SCNBox(width: 0.9, height: 0.4, length: 1.1, chamferRadius: 0.1)
        glass.firstMaterial?.diffuse.contents = UIColor.cyan.withAlphaComponent(0.6)
        let glassNode = SCNNode(geometry: glass)
        glassNode.position = SCNVector3(0, 0.7, 0.3)
        root.addChildNode(glassNode)
        
        return root
    }

    func startEngine() {
        Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { _ in
            guard let car = carNode, let cam = cameraNode else { return }
            
            if isAccelerating { speed = min(speed + accelRate, maxSpeed) }
            else if isBraking { speed = max(speed - accelRate, -0.15) }
            else { speed *= friction }
            
            angle += steering * (speed * 0.15)
            
            car.rotation = SCNVector4(0, 1, 0, angle)
            car.position.x += sin(angle) * speed
            car.position.z += cos(angle) * speed
            
            let ideal = SCNVector3(car.position.x - sin(angle)*7, car.position.y + 3.5, car.position.z - cos(angle)*7)
            cam.position.x += (ideal.x - cam.position.x) * 0.1
            cam.position.y += (ideal.y - cam.position.y) * 0.1
            cam.position.z += (ideal.z - cam.position.z) * 0.1
            cam.look(at: car.position)
        }
    }

    func controlPad(label: String, color: Color = .white, active: Bool, onStart: @escaping () -> Void, onEnd: @escaping () -> Void) -> some View {
        Text(label)
            .font(.system(.body, design: .monospaced)).bold()
            .frame(width: 65, height: 65)
            .background(active ? color.opacity(0.8) : Color.white.opacity(0.15))
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .gesture(DragGesture(minimumDistance: 0).onChanged { _ in onStart() }.onEnded { _ in onEnd() })
    }
    
    func generateGrid() -> UIImage {
        let size = CGSize(width: 64, height: 64)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            context.cgContext.setStrokeColor(UIColor.white.withAlphaComponent(0.3).cgColor)
            context.cgContext.setLineWidth(1.0)
            context.cgContext.stroke(rect)
        }
    }
}
