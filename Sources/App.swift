import SwiftUI
import SceneKit

// MARK: - App Entry Point
@main
struct VibeDriveApp: App {
    var body: some Scene {
        WindowGroup {
            MatrixedMainView()
        }
    }
}

// MARK: - State Management
enum AppState {
    case loading
    case menu
    case playing
}

// MARK: - Main UI View
struct MatrixedMainView: View {
    @StateObject private var engine = GameEngine()
    @State private var currentState: AppState = .loading
    
    var body: some View {
        ZStack {
            // THE 3D LAYER
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    currentState = .menu
                }
            }
        }
    }
    
    var menuView: some View {
        VStack {
            Spacer()
            VStack(spacing: -5) {
                Text("MATRIXED")
                    .font(.system(size: 50, weight: .black, design: .monospaced))
                    .foregroundColor(.cyan)
                    .shadow(color: .cyan.opacity(0.8), radius: 20)
                Text("ENGINE_STABLE // CAM_FIXED").font(.system(.caption2, design: .monospaced)).foregroundColor(.green)
            }
            Spacer()
            Button(action: { 
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { currentState = .playing }
            }) {
                Text("START_SIMULATION")
                    .font(.system(.headline, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 50).padding(.vertical, 18)
                    .background(Color.cyan).cornerRadius(2)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.4))
    }
    
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
                        Image(systemName: "power").font(.title).foregroundColor(.red).padding().background(Color.black.opacity(0.5)).clipShape(Circle())
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

// MARK: - Game Engine
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
        
        let ambient = SCNLight(); ambient.type = .ambient; ambient.intensity = 800
        let ambNode = SCNNode(); ambNode.light = ambient; scene.rootNode.addChildNode(ambNode)

        let directional = SCNLight(); directional.type = .directional; directional.intensity = 2000
        let dNode = SCNNode(); dNode.light = directional; dNode.position = SCNVector3(10, 20, 10)
        scene.rootNode.addChildNode(dNode)

        let floor = SCNFloor(); floor.reflectivity = 0.5
        let floorMat = SCNMaterial(); floorMat.diffuse.contents = UIColor(white: 0.1, alpha: 1.0)
        floor.materials = [floorMat]
        scene.rootNode.addChildNode(SCNNode(geometry: floor))

        // Car Body
        let body = SCNBox(width: 1.8, height: 0.3, length: 4.0, chamferRadius: 0.2)
        body.firstMaterial?.diffuse.contents = UIColor.black
        let bNode = SCNNode(geometry: body); bNode.position = SCNVector3(0, 0.2, 0); carNode.addChildNode(bNode)

        let hood = SCNBox(width: 1.6, height: 0.1, length: 2.0, chamferRadius: 0.1)
        hood.firstMaterial?.diffuse.contents = UIColor.cyan; hood.firstMaterial?.emission.contents = UIColor.cyan
        let hNode = SCNNode(geometry: hood); hNode.position = SCNVector3(0, 0.3, 1.0); carNode.addChildNode(hNode)

        cameraNode.camera = SCNCamera()
        cameraNode.camera?.wantsHDR = true
        cameraNode.camera?.bloomIntensity = 2.5
        cameraNode.position = SCNVector3(0, 20, -40) 
        
        scene.rootNode.addChildNode(carNode)
        scene.rootNode.addChildNode(cameraNode)
    }

    func startLoop() {
        Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { _ in
            DispatchQueue.main.async {
                if self.isAccelerating { self.speed = min(self.speed + 0.02, 1.6) }
                else if self.isBraking { self.speed = max(self.speed - 0.05, -0.6) }
                else { self.speed *= 0.95 }

                self.carAngle += self.steering * (self.speed * 1.2)
                self.carNode.rotation = SCNVector4(0, 1, 0, self.carAngle)
                self.carNode.position.x += sin(self.carAngle) * self.speed
                self.carNode.position.z += cos(self.carAngle) * self.speed

                // High Speed Camera Correction
                let baseLerp: Float = 0.12
                let finalLerp = min(baseLerp + (abs(self.speed) * 0.1), 0.8) 
                
                let dist: Float = 16.0 
                let height: Float = 7.0 
                
                let targetX = self.carNode.position.x - sin(self.carAngle) * dist
                let targetZ = self.carNode.position.z - cos(self.carAngle) * dist
                let targetY = self.carNode.position.y + height
                
                self.cameraNode.position.x += (targetX - self.cameraNode.position.x) * finalLerp
                self.cameraNode.position.z += (targetZ - self.cameraNode.position.z) * finalLerp
                self.cameraNode.position.y += (targetY - self.cameraNode.position.y) * finalLerp
                
                let lookTarget = SCNVector3(
                    self.carNode.position.x + sin(self.carAngle) * 4,
                    self.carNode.position.y + 0.5,
                    self.carNode.position.z + cos(self.carAngle) * 4
                )
                self.cameraNode.look(at: lookTarget, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, 1))
            }
        }
    }
}
