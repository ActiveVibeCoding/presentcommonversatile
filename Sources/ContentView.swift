import SwiftUI
import SceneKit

struct ContentView: View {
    @StateObject private var engine = GameEngine()

    var body: some View {
        ZStack {
            SceneView(
                scene: engine.scene,
                pointOfView: engine.cameraNode,
                options: [.allowsCameraControl]
            )
            .ignoresSafeArea()

            // HUD
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("VIBE_DRIVE_GLOW").font(.system(.title3, design: .monospaced)).bold()
                        Text("VELOCITY: \(Int(abs(engine.speed) * 320))").foregroundColor(.cyan)
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(15)
                    .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.cyan.opacity(0.5), lineWidth: 1))
                    Spacer()
                }
                .padding(.top, 60).padding(.leading, 20)
                Spacer()
            }

            // Pro Controls
            VStack {
                Spacer()
                HStack {
                    HStack(spacing: 25) {
                        controlButton(label: "L", active: engine.steering > 0) { engine.steering = 0.04 } onEnd: { engine.steering = 0 }
                        controlButton(label: "R", active: engine.steering < 0) { engine.steering = -0.04 } onEnd: { engine.steering = 0 }
                    }
                    Spacer()
                    HStack(spacing: 25) {
                        controlButton(label: "OFF", color: .red, active: engine.isBraking) { engine.isBraking = true } onEnd: { engine.isBraking = false }
                        controlButton(label: "ON", color: .cyan, active: engine.isAccelerating) { engine.isAccelerating = true } onEnd: { engine.isAccelerating = false }
                    }
                }
                .padding(40)
            }
        }
    }

    func controlButton(label: String, color: Color = .white, active: Bool, onStart: @escaping () -> Void, onEnd: @escaping () -> Void) -> some View {
        Circle()
            .fill(active ? color.opacity(0.3) : Color.white.opacity(0.05))
            .frame(width: 80, height: 80)
            .overlay(Text(label).font(.headline).foregroundColor(.white))
            .overlay(Circle().stroke(active ? color : Color.white.opacity(0.2), lineWidth: 2))
            .shadow(color: active ? color : .clear, radius: 10)
            .gesture(DragGesture(minimumDistance: 0).onChanged { _ in onStart() }.onEnded { _ in onEnd() })
    }
}

class GameEngine: ObservableObject {
    @Published var scene = SCNScene()
    @Published var speed: Float = 0
    @Published var steering: Float = 0
    @Published var isAccelerating = false
    @Published var isBraking = false
    
    var carNode = SCNNode()
    var cameraNode = SCNNode()
    var carAngle: Float = 0

    init() {
        setupWorld()
        startLoop()
    }

    func setupWorld() {
        scene.background.contents = UIColor.black
        
        // 1. Reflective Floor
        let floor = SCNFloor()
        floor.reflectivity = 0.5
        let floorMat = SCNMaterial()
        floorMat.diffuse.contents = UIColor(white: 0.02, alpha: 1.0)
        floorMat.lightingModel = .physicallyBased
        floor.materials = [floorMat]
        scene.rootNode.addChildNode(SCNNode(geometry: floor))

        // 2. High-Intensity Lights (to trigger the bloom)
        let sun = SCNLight()
        sun.type = .directional
        sun.intensity = 2500
        let sunNode = SCNNode()
        sunNode.light = sun
        sunNode.position = SCNVector3(10, 20, 10)
        sunNode.look(at: SCNVector3(0,0,0))
        scene.rootNode.addChildNode(sunNode)

        // 3. Build Car
        buildExoticCar()
        scene.rootNode.addChildNode(carNode)

        // 4. Camera + GLOW EFFECTS
        let cam = SCNCamera()
        cam.wantsHDR = true
        cam.bloomIntensity = 2.0 // This makes the cyan GLOW
        cam.bloomThreshold = 0.8 // Only bright things glow
        cam.bloomBlurRadius = 15.0
        
        cameraNode.camera = cam
        cameraNode.position = SCNVector3(0, 5, -12)
        scene.rootNode.addChildNode(cameraNode)
    }

    func buildExoticCar() {
        let body = SCNBox(width: 1.6, height: 0.3, length: 3.5, chamferRadius: 0.2)
        
        // Material with "Emission" - this makes it literally emit light
        let bodyMat = SCNMaterial()
        bodyMat.diffuse.contents = UIColor.cyan
        bodyMat.emission.contents = UIColor.cyan.withAlphaComponent(0.4) // Subtle glow
        bodyMat.metalness.contents = 1.0
        bodyMat.roughness.contents = 0.05
        bodyMat.lightingModel = .physicallyBased
        body.materials = [bodyMat]
        
        let node = SCNNode(geometry: body)
        node.position = SCNVector3(0, 0.25, 0)
        carNode.addChildNode(node)

        // Cockpit
        let cabin = SCNPyramid(width: 1.1, height: 0.5, length: 1.5)
        cabin.firstMaterial?.diffuse.contents = UIColor.black
        let cabinNode = SCNNode(geometry: cabin)
        cabinNode.position = SCNVector3(0, 0.4, -0.3)
        cabinNode.rotation = SCNVector4(1, 0, 0, Float.pi)
        carNode.addChildNode(cabinNode)

        // Wheels
        let wheelGeo = SCNCylinder(radius: 0.35, height: 0.3)
        wheelMat(wheelGeo)
        let positions = [SCNVector3(0.8, 0.3, 1.0), SCNVector3(-0.8, 0.3, 1.0), 
                         SCNVector3(0.8, 0.3, -1.0), SCNVector3(-0.8, 0.3, -1.0)]
        for pos in positions {
            let wheel = SCNNode(geometry: wheelGeo)
            wheel.position = pos
            wheel.rotation = SCNVector4(0, 0, 1, Float.pi/2)
            carNode.addChildNode(wheel)
        }
    }

    func wheelMat(_ geo: SCNCylinder) {
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor.black
        mat.metalness.contents = 0.5
        geo.materials = [mat]
    }

    func startLoop() {
        Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { _ in
            DispatchQueue.main.async {
                if self.isAccelerating { self.speed = min(self.speed + 0.015, 1.2) }
                else if self.isBraking { self.speed = max(self.speed - 0.035, -0.4) }
                else { self.speed *= 0.96 }

                if abs(self.speed) > 0.01 {
                    self.carAngle += self.steering * (self.speed * 1.5)
                }

                self.carNode.rotation = SCNVector4(0, 1, 0, self.carAngle)
                self.carNode.position.x += sin(self.carAngle) * self.speed
                self.carNode.position.z += cos(self.carAngle) * self.speed

                let lerp: Float = 0.1
                let targetX = self.carNode.position.x - sin(self.carAngle) * 11.0
                let targetZ = self.carNode.position.z - cos(self.carAngle) * 11.0
                
                self.cameraNode.position.x += (targetX - self.cameraNode.position.x) * lerp
                self.cameraNode.position.z += (targetZ - self.cameraNode.position.z) * lerp
                self.cameraNode.position.y += ((self.carNode.position.y + 4.5) - self.cameraNode.position.y) * lerp
                
                self.cameraNode.look(at: self.carNode.position, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, 1))
            }
        }
    }
}
