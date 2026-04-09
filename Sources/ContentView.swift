import SwiftUI
import SceneKit

// 

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
        
        // Lighting
        let ambient = SCNLight(); ambient.type = .ambient; ambient.intensity = 800
        scene.rootNode.addChildNode(SCNNode()); scene.rootNode.childNodes.last?.light = ambient

        let directional = SCNLight(); directional.type = .directional; directional.intensity = 2000
        let dNode = SCNNode(); dNode.light = directional; dNode.position = SCNVector3(10, 20, 10)
        scene.rootNode.addChildNode(dNode)

        // Floor
        let floor = SCNFloor(); floor.reflectivity = 0.5
        let floorMat = SCNMaterial(); floorMat.diffuse.contents = UIColor(white: 0.1, alpha: 1.0)
        floor.materials = [floorMat]
        scene.rootNode.addChildNode(SCNNode(geometry: floor))

        // Car Body
        let body = SCNBox(width: 1.8, height: 0.3, length: 4.0, chamferRadius: 0.2)
        body.firstMaterial?.diffuse.contents = UIColor.black
        let bNode = SCNNode(geometry: body); bNode.position = SCNVector3(0, 0.2, 0); carNode.addChildNode(bNode)

        // Glow Hood
        let hood = SCNBox(width: 1.6, height: 0.1, length: 2.0, chamferRadius: 0.1)
        hood.firstMaterial?.diffuse.contents = UIColor.cyan; hood.firstMaterial?.emission.contents = UIColor.cyan
        let hNode = SCNNode(geometry: hood); hNode.position = SCNVector3(0, 0.3, 1.0); carNode.addChildNode(hNode)

        // Camera Initialization
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.wantsHDR = true
        cameraNode.camera?.bloomIntensity = 2.5
        // Start the camera VERY far away so it has to zoom in, rather than starting inside
        cameraNode.position = SCNVector3(0, 20, -40) 
        
        scene.rootNode.addChildNode(carNode)
        scene.rootNode.addChildNode(cameraNode)
    }

    func startLoop() {
        Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { _ in
            DispatchQueue.main.async {
                // 1. Physics Logic
                if self.isAccelerating { self.speed = min(self.speed + 0.02, 1.6) }
                else if self.isBraking { self.speed = max(self.speed - 0.05, -0.6) }
                else { self.speed *= 0.95 }

                self.carAngle += self.steering * (self.speed * 1.2)
                self.carNode.rotation = SCNVector4(0, 1, 0, self.carAngle)
                self.carNode.position.x += sin(self.carAngle) * self.speed
                self.carNode.position.z += cos(self.carAngle) * self.speed

                // 2. CAMERA FIX: Adaptive Lerp
                // If we are going fast, we make the camera move FASTER (stiffer) 
                // so it doesn't fall behind and end up inside the car.
                let baseLerp: Float = 0.12
                let speedFactor = abs(self.speed) * 0.1 // Increases "snappiness" with speed
                let finalLerp = min(baseLerp + speedFactor, 0.8) 
                
                let dist: Float = 16.0 
                let height: Float = 7.0 
                
                let targetX = self.carNode.position.x - sin(self.carAngle) * dist
                let targetZ = self.carNode.position.z - cos(self.carAngle) * dist
                let targetY = self.carNode.position.y + height
                
                // Move Camera
                self.cameraNode.position.x += (targetX - self.cameraNode.position.x) * finalLerp
                self.cameraNode.position.z += (targetZ - self.cameraNode.position.z) * finalLerp
                self.cameraNode.position.y += (targetY - self.cameraNode.position.y) * finalLerp
                
                // Look slightly IN FRONT of the car so the car is in the lower 1/3rd of the screen
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
