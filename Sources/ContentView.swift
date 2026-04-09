import SwiftUI
import SceneKit

enum AppState {
    case menu
    case playing
}

struct ContentView: View {
    @StateObject private var engine = GameEngine()
    @State private var currentState: AppState = .menu
    
    var body: some View {
        ZStack {
            // Background 3D View (Always running subtlely)
            SceneView(
                scene: engine.scene,
                pointOfView: engine.cameraNode,
                options: []
            )
            .ignoresSafeArea()
            .blur(radius: currentState == .menu ? 10 : 0) // Blur the game when in menu
            
            // --- UI LAYER ---
            Group {
                if currentState == .menu {
                    menuView
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else {
                    gameplayView
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: currentState)
    }
    
    // MARK: - Menu UI
    var menuView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            VStack(spacing: 10) {
                Text("MATRIXED")
                    .font(.system(size: 50, weight: .black, design: .monospaced))
                    .foregroundColor(.cyan)
                    .tracking(10)
                    .shadow(color: .cyan, radius: 20)
                
                Text("NEURAL_LINK_ESTABLISHED")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.green.opacity(0.8))
            }
            
            Spacer()
            
            Button(action: { currentState = .playing }) {
                HStack {
                    Text("INITIALIZE_ENGINE")
                    Image(systemName: "bolt.fill")
                }
                .font(.system(.headline, design: .monospaced))
                .padding(.horizontal, 40)
                .padding(.vertical, 20)
                .background(Color.cyan.opacity(0.1))
                .foregroundColor(.cyan)
                .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.cyan, lineWidth: 2))
            }
            .scaleEffect(1.1)
            
            Text("V.1.04_STABLE")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.white.opacity(0.3))
                .padding(.bottom, 40)
        }
    }
    
    // MARK: - Gameplay UI
    var gameplayView: some View {
        ZStack {
            // Top HUD
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("NODE: MATRIXED_OS").font(.system(.caption2, design: .monospaced)).foregroundColor(.cyan)
                        Text("SPD: \(Int(abs(engine.speed) * 350)) KM/H").font(.system(.title2, design: .monospaced)).bold()
                    }
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(5)
                    Spacer()
                    
                    Button(action: { currentState = .menu }) {
                        Image(systemName: "arrow.left")
                            .padding()
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                            .foregroundColor(.white)
                    }
                }
                .padding(.top, 60).padding(.horizontal, 20)
                Spacer()
            }
            
            // Bottom Controls
            VStack {
                Spacer()
                HStack {
                    HStack(spacing: 20) {
                        controlButton(label: "L", active: engine.steering > 0) { engine.steering = 0.045 } onEnd: { engine.steering = 0 }
                        controlButton(label: "R", active: engine.steering < 0) { engine.steering = -0.045 } onEnd: { engine.steering = 0 }
                    }
                    Spacer()
                    HStack(spacing: 20) {
                        controlButton(label: "REV", color: .red, active: engine.isBraking) { engine.isBraking = true } onEnd: { engine.isBraking = false }
                        controlButton(label: "GAS", color: .cyan, active: engine.isAccelerating) { engine.isAccelerating = true } onEnd: { engine.isAccelerating = false }
                    }
                }
                .padding(40)
            }
        }
    }

    func controlButton(label: String, color: Color = .white, active: Bool, onStart: @escaping () -> Void, onEnd: @escaping () -> Void) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(active ? color.opacity(0.3) : Color.white.opacity(0.05))
            .frame(width: 70, height: 70)
            .overlay(Text(label).font(.system(.headline, design: .monospaced)).foregroundColor(.white))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(active ? color : Color.white.opacity(0.2), lineWidth: 1.5))
            .shadow(color: active ? color : .clear, radius: 10)
            .gesture(DragGesture(minimumDistance: 0).onChanged { _ in onStart() }.onEnded { _ in onEnd() })
    }
}

// MARK: - Game Engine (Keep same logic, but improved visuals)
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
        
        let floor = SCNFloor()
        floor.reflectivity = 0.5
        let floorMat = SCNMaterial()
        floorMat.diffuse.contents = UIColor(white: 0.02, alpha: 1.0)
        floorMat.lightingModel = .physicallyBased
        floor.materials = [floorMat]
        scene.rootNode.addChildNode(SCNNode(geometry: floor))

        let sun = SCNLight()
        sun.type = .directional
        sun.intensity = 2000
        let sunNode = SCNNode()
        sunNode.light = sun
        sunNode.position = SCNVector3(10, 20, 10)
        scene.rootNode.addChildNode(sunNode)

        buildCar()
        scene.rootNode.addChildNode(carNode)

        let cam = SCNCamera()
        cam.wantsHDR = true
        cam.bloomIntensity = 2.5
        cameraNode.camera = cam
        cameraNode.position = SCNVector3(0, 8, -15)
        scene.rootNode.addChildNode(cameraNode)
    }

    func buildCar() {
        // Chassis
        let bodyGeo = SCNBox(width: 1.8, height: 0.3, length: 4.0, chamferRadius: 0.2)
        bodyGeo.firstMaterial?.diffuse.contents = UIColor.black
        bodyGeo.firstMaterial?.metalness.contents = 1.0
        let bodyNode = SCNNode(geometry: bodyGeo); bodyNode.position = SCNVector3(0, 0.2, 0); carNode.addChildNode(bodyNode)

        // Glow Accents
        let hoodGeo = SCNBox(width: 1.6, height: 0.1, length: 2.0, chamferRadius: 0.1)
        hoodGeo.firstMaterial?.diffuse.contents = UIColor.cyan
        hoodGeo.firstMaterial?.emission.contents = UIColor.cyan.withAlphaComponent(0.4)
        let hoodNode = SCNNode(geometry: hoodGeo); hoodNode.position = SCNVector3(0, 0.3, 1.0); carNode.addChildNode(hoodNode)
        
        // Spoiler
        let wing = SCNBox(width: 1.9, height: 0.05, length: 0.5, chamferRadius: 0)
        wing.firstMaterial?.diffuse.contents = UIColor.cyan
        let wingNode = SCNNode(geometry: wing); wingNode.position = SCNVector3(0, 0.7, -1.8); carNode.addChildNode(wingNode)
    }

    func startLoop() {
        Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { _ in
            DispatchQueue.main.async {
                if self.isAccelerating { self.speed = min(self.speed + 0.02, 1.4) }
                else if self.isBraking { self.speed = max(self.speed - 0.05, -0.4) }
                else { self.speed *= 0.95 }

                self.carAngle += self.steering * (self.speed * 1.2)
                self.carNode.rotation = SCNVector4(0, 1, 0, self.carAngle)
                self.carNode.position.x += sin(self.carAngle) * self.speed
                self.carNode.position.z += cos(self.carAngle) * self.speed

                let lerp: Float = 0.08
                let targetX = self.carNode.position.x - sin(self.carAngle) * 16.0
                let targetZ = self.carNode.position.z - cos(self.carAngle) * 16.0
                
                self.cameraNode.position.x += (targetX - self.cameraNode.position.x) * lerp
                self.cameraNode.position.z += (targetZ - self.cameraNode.position.z) * lerp
                self.cameraNode.position.y += (8.0 - self.cameraNode.position.y) * lerp
                self.cameraNode.look(at: self.carNode.position, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, 1))
            }
        }
    }
}
