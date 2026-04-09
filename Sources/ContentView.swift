import SwiftUI
import SceneKit

struct ContentView: View {
    // Using a dedicated Scene class to keep the engine running smoothly
    @StateObject private var engine = GameEngine()

    var body: some View {
        ZStack {
            SceneView(
                scene: engine.scene,
                pointOfView: engine.cameraNode,
                options: [.allowsCameraControl, .autoenablesDefaultLighting]
            )
            .ignoresSafeArea()

            // HUD
            VStack {
                HStack {
                    VStack(alignment: .leading) {
                        Text("VIBE_DRIVE_ULTRA").bold()
                        Text("SPEED: \(Int(engine.speed * 200)) KM/H")
                            .foregroundColor(.green)
                            .italic()
                    }
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .background(BlurView(style: .systemThinMaterialDark))
                    .cornerRadius(12)
                    Spacer()
                }
                .padding(.top, 60).padding(.leading, 20)
                Spacer()
            }

            // Controls
            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    // Steering
                    HStack(spacing: 20) {
                        controlButton(label: "←", active: engine.steering > 0) { engine.steering = 0.03 } onEnd: { engine.steering = 0 }
                        controlButton(label: "→", active: engine.steering < 0) { engine.steering = -0.03 } onEnd: { engine.steering = 0 }
                    }
                    Spacer()
                    // Pedals
                    HStack(spacing: 20) {
                        controlButton(label: "BRAKE", color: .red, active: engine.isBraking) { engine.isBraking = true } onEnd: { engine.isBraking = false }
                        controlButton(label: "DRIVE", color: .green, active: engine.isAccelerating) { engine.isAccelerating = true } onEnd: { engine.isAccelerating = false }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 50)
            }
        }
    }

    func controlButton(label: String, color: Color = .white, active: Bool, onStart: @escaping () -> Void, onEnd: @escaping () -> Void) -> some View {
        Text(label)
            .font(.system(.headline, design: .monospaced))
            .frame(width: 80, height: 80)
            .background(active ? color.opacity(0.6) : Color.white.opacity(0.1))
            .foregroundColor(.white)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
            .gesture(DragGesture(minimumDistance: 0).onChanged { _ in onStart() }.onEnded { _ in onEnd() })
    }
}

// THE ENGINE: This handles the actual 3D logic separately from the UI
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
        
        // Realistic Ground: Reflective and Dark
        let floor = SCNFloor()
        floor.reflectivity = 0.25
        floor.reflectionFalloffEnd = 10
        let floorMaterial = SCNMaterial()
        floorMaterial.diffuse.contents = UIColor(white: 0.1, alpha: 1.0)
        floorMaterial.lightingModel = .physicallyBased
        floor.materials = [floorMaterial]
        scene.rootNode.addChildNode(SCNNode(geometry: floor))

        // High-End Lighting
        let envLight = SCNLight()
        envLight.type = .probe
        scene.rootNode.light = envLight

        let spot = SCNLight()
        spot.type = .directional
        spot.intensity = 1500
        let spotNode = SCNNode()
        spotNode.light = spot
        spotNode.position = SCNVector3(10, 20, 10)
        spotNode.eulerAngles = SCNVector3(-Float.pi/3, 0, 0)
        scene.rootNode.addChildNode(spotNode)

        // The Car: Modern Sports Aesthetic
        let bodyGeo = SCNBox(width: 1.4, height: 0.4, length: 3.0, chamferRadius: 0.3)
        bodyGeo.firstMaterial?.diffuse.contents = UIColor.systemRed
        bodyGeo.firstMaterial?.metalness.contents = 1.0
        bodyGeo.firstMaterial?.roughness.contents = 0.1
        bodyGeo.firstMaterial?.lightingModel = .physicallyBased
        
        carNode.geometry = bodyGeo
        carNode.position = SCNVector3(0, 0.2, 0)
        scene.rootNode.addChildNode(carNode)

        // Cabin/Cockpit
        let cabinGeo = SCNBox(width: 1.0, height: 0.4, length: 1.2, chamferRadius: 0.2)
        cabinGeo.firstMaterial?.diffuse.contents = UIColor.black
        let cabinNode = SCNNode(geometry: cabinGeo)
        cabinNode.position = SCNVector3(0, 0.35, -0.2)
        carNode.addChildNode(cabinNode)

        // Camera
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zFar = 2000
        cameraNode.camera?.motionBlurIntensity = 0.5
        cameraNode.position = SCNVector3(0, 5, -10)
        scene.rootNode.addChildNode(cameraNode)
    }

    func startLoop() {
        Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { _ in
            DispatchQueue.main.async {
                // Acceleration Logic
                if self.isAccelerating { self.speed = min(self.speed + 0.01, 0.8) }
                else if self.isBraking { self.speed = max(self.speed - 0.02, -0.2) }
                else { self.speed *= 0.98 }

                // Turning Logic
                if abs(self.speed) > 0.01 {
                    self.carAngle += self.steering * (self.speed * 2.0)
                }

                // Apply Transforms
                self.carNode.rotation = SCNVector4(0, 1, 0, self.carAngle)
                self.carNode.position.x += sin(self.carAngle) * self.speed
                self.carNode.position.z += cos(self.carAngle) * self.speed

                // Smooth Camera Follow
                let targetCamPos = SCNVector3(
                    self.carNode.position.x - sin(self.carAngle) * 8,
                    self.carNode.position.y + 4,
                    self.carNode.position.z - cos(self.carAngle) * 8
                )
                
                self.cameraNode.position.x += (targetCamPos.x - self.cameraNode.position.x) * 0.1
                self.cameraNode.position.y += (targetCamPos.y - self.cameraNode.position.y) * 0.1
                self.cameraNode.position.z += (targetCamPos.z - self.cameraNode.position.z) * 0.1
                self.cameraNode.look(at: self.carNode.position)
            }
        }
    }
}

// Utility for blurred HUD background
struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}
