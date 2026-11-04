import ARKit
import SceneKit
import SwiftUI

struct ARPassthroughView: UIViewRepresentable {
    let session: ARSession

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.session = session
        view.automaticallyUpdatesLighting = true
        view.scene = SCNScene()
        view.backgroundColor = .black
        view.rendersContinuously = true
        return view
    }

    func updateUIView(_ view: ARSCNView, context: Context) {
        guard !context.coordinator.didPlaceDemoObject,
              let frame = session.currentFrame else { return }
        let cameraTransform = frame.camera.transform
        let localOffset = SIMD4<Float>(0.0, -0.05, -0.75, 1.0)
        let world = cameraTransform * localOffset

        let sphere = SCNSphere(radius: 0.045)
        sphere.segmentCount = 24
        sphere.firstMaterial?.diffuse.contents = UIColor.systemCyan
        sphere.firstMaterial?.emission.contents = UIColor.cyan
        let node = SCNNode(geometry: sphere)
        node.position = SCNVector3(world.x, world.y, world.z)
        view.scene.rootNode.addChildNode(node)

        let ring = SCNTorus(ringRadius: 0.085, pipeRadius: 0.004)
        ring.firstMaterial?.diffuse.contents = UIColor.white
        let ringNode = SCNNode(geometry: ring)
        ringNode.position = node.position
        view.scene.rootNode.addChildNode(ringNode)
        context.coordinator.didPlaceDemoObject = true
    }

    final class Coordinator {
        var didPlaceDemoObject = false
    }
}
