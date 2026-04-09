import SwiftUI
import SceneKit

enum AppState {
    case loading
    case menu
    case playing
}

struct ContentView: View {
    @StateObject private var engine = GameEngine()
    @State private var currentState: AppState = .loading
    
    var body: some View {
        ZStack {
            // THE 3D LAYER - Always present
            SceneView(
                scene: engine.scene,
                pointOfView: engine.cameraNode,
                options: []
            )
            .edgesIgnoringSafeArea(.all)
            .blur(radius: currentState == .menu ? 12 : 0)
            .background(Color.black)

            // THE UI LAYER
            ZStack {
                if currentState == .menu {
                    menuView
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 1.1)),
                            removal: .move(edge: .leading).combined(with: .opacity).combined(with: .scale(scale: 0.9))
                        ))
                } else if currentState == .playing {
                    gameplayView
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity).combined(with: .scale(scale: 1.1)),
                            removal: .opacity
                        ))
                }
            }
        }
        .onAppear {
            // Small delay to let the GPU wake up before showing the UI
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    currentState = .menu
                }
            }
        }
    }
    
    // MARK: - Menu View
    var menuView: some View {
        VStack {
            Spacer()
            VStack(spacing: -5) {
                Text("MATRIXED")
                    .font(.system(size: 50, weight: .black, design: .monospaced))
                    .foregroundColor(.cyan)
                    .shadow(color: .cyan.opacity(0.8), radius: 20)
                Text("STABLE_BUILD_4.0").font(.system(.caption2, design: .monospaced)).foregroundColor(.green)
            }
            
            Spacer()
            
            Button(action: { 
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { currentState = .playing }
            }) {
                Text("RUN_SIMULATION")
                    .font(.system(.headline, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 50)
                    .padding(.vertical, 18)
                    .background(Color.cyan)
                    .cornerRadius(2)
                    .shadow(color: .cyan.opacity(0.5), radius: 15)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.4))
    }
    
    // MARK: - Gameplay View
    var gameplayView: some View {
        ZStack {
            VStack {
                HStack {
                    VStack(alignment: .leading) {
                        Text("NODE: MATRIXED").font(.system(.caption2, design: .monospaced)).foregroundColor(.cyan)
                        Text("\(Int(abs(engine.speed) * 350))").font(.system(.title, design: .monospaced)).bold().foregroundColor(.white)
                    }
                    .padding().background(Color.black.opacity(0.6)).cornerRadius(10)
                    Spacer()
                    Button(action: { withAnimation { currentState = .menu } }) {
                        Image(systemName: "xmark.circle.fill").font(.title).foregroundColor(.red).padding().background(Color.black.opacity(0.5)).clipShape(Circle())
                    }
                }
                .padding(.top, 60).padding(.horizontal, 25)
                Spacer()
            }
            
            VStack {
                Spacer()
                HStack {
                    HStack(spacing: 20) {
                        controlButton(label: "L", active: engine.steering > 0) { engine.steering = 0.045 } onEnd: { engine.steering = 0 }
                        controlButton(label: "R", active: engine.steering < 0) { engine.steering = -0.045 } onEnd: { engine.steering = 0 }
                    }
                    Spacer()
                    HStack(spacing: 20) {
                        controlButton(label: "B", color: .red, active: engine.isBraking) { engine.isBraking = true } onEnd: { engine.isBraking = false }
                        controlButton(label: "A", color: .cyan, active: engine.isAccelerating) { engine.isAccelerating = true } onEnd: { engine.isAccelerating = false }
                    }
                }
                .padding(40)
            }
        }
    }

    func controlButton(label: String, color: Color = .white, active: Bool, onStart: @escaping () -> Void, onEnd: @escaping () -> Void) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(active ? color.opacity(0.4) : Color.white.opacity(0.1))
            .frame(width: 75, height: 75)
            .overlay(Text(label).font(.system(.title2, design: .monospaced)).bold().foregroundColor(.white))
            .shadow(color: active ? color : .clear, radius: 10)
            .gesture(DragGesture(minimumDistance: 0).onChanged { _ in onStart() }.onEnded { _ in onEnd() })
    }
}

// MARK: - Engine
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
        
        // --- 1. AMBIENT LIGHT FIX ---
        // This ensures the scene is NEVER black, even if directional lights fail
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 500 // Strong base light
        let ambNode = SCNNode(); ambNode.light = ambient
        scene.rootNode.addChildNode(ambNode)

        let directional = SCNLight()
        directional.type = .directional
        directional.intensity = 2000
        let dNode = SCNNode(); dNode.light = directional; dNode.position = SCNVector3(10, 20, 10)
        scene.rootNode.addChildNode(dNode)

        // 2. Floor
        let floor = SCNFloor()
        floor.reflectivity = 0.5
        let floorMat = SCNMaterial()
        floorMat.diffuse.contents = UIColor(white: 0.05, alpha: 1.0)
        floorMat.lightingModel = .physicallyBased
        floor.materials = [floorMat]
        scene.rootNode.addChildNode(SCNNode(geometry: floor))

        // 3. Build Car
        let body = SCNBox(width: 1.8, height: 0.3, length: 4.0, chamferRadius: 0.2)
        body.firstMaterial?.diffuse.contents = UIColor.black
        body.firstMaterial?.metalness.contents = 1.0
        let bNode = SCNNode(geometry: body); bNode.position = SCNVector3(0, 0.2, 0); carNode.addChildNode(bNode)

        let hood = SCNBox(width: 1.6, height: 0.1, length: 2.0, chamferRadius: 0.1)
        hood.firstMaterial?.diffuse.contents = UIColor.cyan
        hood.firstMaterial?.emission.contents = UIColor.cyan.withAlphaComponent(0.8) // GLOW
        let hNode = SCNNode(geometry: hood); hNode.position = SCNVector3(0, 0.3, 1.0); carNode.addChildNode(hNode)

        // 4. Camera
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.wantsHDR = true
        cameraNode.camera?.bloomIntensity = 2.5
        cameraNode.position = SCNVector3(0, 8, -18)
        scene.rootNode.addChildNode(carNode)
        scene.rootNode.addChildNode(cameraNode)
    }

    func startLoop() {
        Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { _ in
            DispatchQueue.main.async {
                if self.isAccelerating { self.speed = min(self.speed + 0.02, 1.5) }
                else if self.isBraking { self.speed = max(self.speed - 0.05, -0.5) }
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
