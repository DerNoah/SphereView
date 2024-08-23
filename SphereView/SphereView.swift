//
//  SphereView.swift
//  SphereView
//
//  Created by Noah Plützer on 23.08.24.
//

import simd
import UIKit

open class SphereView: UIView {
    /// the radius of sphere
    open var sphereRadius: CGFloat { didSet { positionSubviews() }}
    
    /// subviews of contentView will be layouted as sphere
    open var contentView = UIView()
    
    open var scrollSensitivity: CGFloat = 0.01
    
    open var adjustAlphaWithZPosition: Bool = true { didSet { positionSubviews() }}
    
    open var isScrollEnabled: Bool = true {
        didSet {
            if isPinchEnabled {
                addGestureRecognizer(panGestureRecognizer)
            } else {
                removeGestureRecognizer(panGestureRecognizer)
            }
        }
    }
    
    open var isPinchEnabled: Bool = true {
        didSet {
            if isPinchEnabled {
                addGestureRecognizer(pinchGestureRecognizer)
            } else {
                removeGestureRecognizer(pinchGestureRecognizer)
            }
        }
    }
    
    private var globalRotation = simd_quatd(ix: 0, iy: 0, iz: 0, r: 1) // identity quaternion
    
    private var currentDecelerationTimer: Timer?
    
    private lazy var lastPinchScale: CGFloat = sphereRadius
    
    private lazy var panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
    private lazy var pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
    
    public override init(frame: CGRect) {
        self.sphereRadius = frame.size.width / 2
        super.init(frame: frame)
        setup()
    }
    
    public required init?(coder: NSCoder) {
        self.sphereRadius = 1
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        addSubview(contentView)
        
        addGestureRecognizer(panGestureRecognizer)
        addGestureRecognizer(pinchGestureRecognizer)
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        contentView.frame = frame
        positionSubviews()
    }
    
    private func cancelCurrentPanDeceleration() {
        currentDecelerationTimer?.invalidate()
    }
    
    /// rotates around given axis
    /// animatable
    func setRotationOffset(xAxis: Double, yAxis: Double) {
        cancelCurrentPanDeceleration()
        globalRotation = rotateSphereWithGlobalAxes(globalRotation: globalRotation, deltaX: yAxis, deltaY: xAxis)
        positionSubviews()
    }
    
    /// resets current rotation
    /// animatable
    public func resetRotation() {
        cancelCurrentPanDeceleration()
        globalRotation = rotateSphereWithGlobalAxes(globalRotation: globalRotation, deltaX: 0, deltaY: 0)
        positionSubviews()
    }
    
    /// resets sphere scale
    /// animatable
    public func resetZoom() {
        sphereRadius = frame.size.width / 2
        lastPinchScale = sphereRadius
    }
    
    /// resets sphere rotation and zoom to origin
    /// animatable
    public func resetTransform() {
        cancelCurrentPanDeceleration()
        resetRotation()
        resetZoom()
        invalidateLayout()
    }
    
    /// calculates a layout that fits into space
    /// animatable
    public func invalidateLayout() {
        let averageViewSize = contentView.subviews.reduce(CGFloat.zero) { partialResult, element in
            partialResult + element.bounds.width
        } / CGFloat(contentView.subviews.count)
        
        let itemsFitInWidth = bounds.width / averageViewSize
        let newRadius = itemsFitInWidth * averageViewSize
        
        sphereRadius = newRadius
        lastPinchScale = newRadius
    }
    
    private func positionSubviews() {
        let spherePositions = fibonacciSphere(numberOfPoints: contentView.subviews.count)
        
        for (i, view) in contentView.subviews.reversed().enumerated() {
            // Calculate spherical position
            let x = (spherePositions[i].x * sphereRadius) + contentView.bounds.width / 2
            let y = (spherePositions[i].y * sphereRadius) + contentView.bounds.height / 2
            let z: CGFloat = spherePositions[i].z // -1.0 to +1.0
            let normalizedZ = ((z + 1) / 2)
            
            let transformedZ = max(1 - normalizedZ, 0.3) // 0.3 to 1.0
            
            view.center = CGPoint(x: x, y: y)
            
            view.transform = CGAffineTransform(scaleX: transformedZ, y: transformedZ)
            
            if adjustAlphaWithZPosition {
                view.alpha = transformedZ + 0.1
            }
            
            view.layer.zPosition = transformedZ
            view.isUserInteractionEnabled = z < 0
        }
    }
    
    // MARK: Fibonacci Sphere
    
    private func fibonacciSphere(numberOfPoints: Int) -> [(x: Double, y: Double, z: Double)] {
        let phi = (1.0 + sqrt(5.0)) / 2.0 // golden ratio
        var points = [(x: Double, y: Double, z: Double)]()
        
        for i in 0..<numberOfPoints {
            let iDouble = Double(i)
            let theta = acos(1 - 2 * (iDouble + 0.5) / Double(numberOfPoints))
            let phi_i = 2 * Double.pi * (iDouble / phi).truncatingRemainder(dividingBy: 1)
            
            // Spherical coordinates to Cartesian
            let x = sin(theta) * cos(phi_i)
            let y = sin(theta) * sin(phi_i)
            let z = cos(theta)
            
            // Apply rotation
            let rotatedPoint = applyQuaternion(point: (x, y, z), quaternion: globalRotation)
            
            points.append(rotatedPoint)
        }
        
        return points
    }
    
    // MARK: Pinch Gesture
    
    @objc
    private func handlePinchGesture(_ sender: UIPinchGestureRecognizer) {
        let pinchScale = (sender.scale * lastPinchScale)
        
        switch sender.state {
            case .changed:
                sphereRadius = pinchScale
            case .ended:
                lastPinchScale = pinchScale
            default:
                break
        }
    }
    
    // MARK: Pan Gesture
    
    @objc
    private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        let deltaX = -Double(translation.x)
        let deltaY = Double(translation.y)
        
        switch gesture.state {
            case .began:
                cancelCurrentPanDeceleration()
            case .changed:
                // Apply the rotation to the sphere's global rotation quaternion
                globalRotation = rotateSphereWithGlobalAxes(globalRotation: globalRotation, deltaX: deltaX, deltaY: deltaY, sensitivity: scrollSensitivity)
                positionSubviews()
            case .ended:
                deceleratePanGesture(velocity: gesture.velocity(in: self))
            default:
                break
        }
        
        // Reset the gesture's translation to avoid compounding deltas
        gesture.setTranslation(.zero, in: self)
    }
    
    private func deceleratePanGesture(velocity: CGPoint) {
        let decelerationRate = UIScrollView.DecelerationRate.fast.rawValue
        let decelerationMultiplier = decelerationRate / 1.01
        
        var currentVelocity = CGPoint(x: velocity.x / 100, y: velocity.y / 100)
        
        currentDecelerationTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            
            currentVelocity = CGPoint(
                x: currentVelocity.x * decelerationMultiplier,
                y: currentVelocity.y * decelerationMultiplier
            )
            
            let deltaX = -Double(currentVelocity.x)
            let deltaY = Double(currentVelocity.y)
            
            self.globalRotation = self.rotateSphereWithGlobalAxes(globalRotation: self.globalRotation, deltaX: deltaX, deltaY: deltaY, sensitivity: scrollSensitivity)
            self.positionSubviews()
            
            if abs(currentVelocity.x) < 0.1 && abs(currentVelocity.y) < 0.1 {
                timer.invalidate()
            }
        }
    }
}

// MARK: Rotation Helper

extension SphereView {
    private func rotateSphereWithGlobalAxes(
        globalRotation: simd_quatd,
        deltaX: Double,
        deltaY: Double,
        sensitivity: Double = 0.01
    ) -> simd_quatd {
        // Convert the pan deltas into rotation angles (radians)
        let rotationX = deltaY * sensitivity
        let rotationY = deltaX * sensitivity
        
        // Create quaternions for the rotations around the global axes
        let quaternionX = simd_quaternion(rotationX, simd_double3(1, 0, 0))
        let quaternionY = simd_quaternion(rotationY, simd_double3(0, 1, 0))
        
        // Combine the rotations: Y then X to ensure global axis orientation
        let newRotation = quaternionY * quaternionX
        
        // Apply the new rotation to the existing global rotation
        let updatedGlobalRotation = newRotation * globalRotation
        
        // Normalize the quaternion to maintain consistent behavior
        return simd_normalize(updatedGlobalRotation)
    }
    
    private func applyQuaternion(point: (x: Double, y: Double, z: Double), quaternion: simd_quatd) -> (x: Double, y: Double, z: Double) {
        let p = simd_double3(point.x, point.y, point.z)
        let rotatedPoint = quaternion.act(p)
        return (x: rotatedPoint.x, y: rotatedPoint.y, z: rotatedPoint.z)
    }
}
