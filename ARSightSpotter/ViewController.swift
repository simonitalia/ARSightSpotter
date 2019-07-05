//
//  ViewController.swift
//  ARSightSpotter
//
//  Created by Simon Italia on 6/24/19.
//  Copyright © 2019 Magical Tomato. All rights reserved.
//

import UIKit
import SpriteKit
import ARKit
import CoreLocation

class ViewController: UIViewController, ARSKViewDelegate, CLLocationManagerDelegate {
    
    let locationManager = CLLocationManager()
    var userLocation = CLLocation()
    
    //Artificial Locations
    let londonLat = 51.5073509
    let londonLon = -0.1277583
    
    var sightsJSON: JSON!
    var userHeading = 0.0
    var headingCount = 0
    
    var pagesDict = [UUID: String]()
    
    @IBOutlet var sceneView: ARSKView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and node count
        sceneView.showsFPS = true
        sceneView.showsNodeCount = true
        
        // Load the SKScene from 'Scene.sks'
        if let scene = SKScene(fileNamed: "Scene") {
            sceneView.presentScene(scene)
        }
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = AROrientationTrackingConfiguration()

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    // MARK: - ARSKViewDelegate
    
    // Create and configure a node for the anchor added to the view's session.
    func view(_ view: ARSKView, nodeFor anchor: ARAnchor) -> SKNode? {
        
        //Create Title Label node at this anchor point, and position text within label node
        let titleNode = SKLabelNode(text: pagesDict[anchor.identifier])
        titleNode.horizontalAlignmentMode  = .center
        titleNode.verticalAlignmentMode = .center
        
        //Scale up the Title label size so we have some padding
        let size = titleNode.frame.size.applying(CGAffineTransform(scaleX: 1.1, y: 1.4))
        
        //Create background node, fill with random color, set border/stroke
        let backgroundNode = SKShapeNode(rectOf: size, cornerRadius: 10)
        backgroundNode.fillColor = UIColor(hue: CGFloat.random(in: 0...1), saturation: 0.5, brightness: 0.4, alpha: 0.9)
        backgroundNode.strokeColor = backgroundNode.fillColor.withAlphaComponent(1)
        backgroundNode.lineWidth = 2
        
        //Add titleNode as child to backgroundNode, return parent node to scene
        backgroundNode.addChild(titleNode)
        return backgroundNode
        
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse {
            locationManager.requestLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error.localizedDescription)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        //Get and set user's current locations, from locations array
        guard let location = locations.last else { return }
        userLocation = location
        
        //Fetch sight info from wikipedia API via background thread
        DispatchQueue.global().async {
            self.fetchSightsData()
        }
        
    }
    
    func fetchSightsData() {
        
        //Pass in users location to urlString
        let urlString =
        
        //Actual lat / long inputs for fetched wiki data
        "https://en.wikipedia.org/w/api.php?ggscoord=\(userLocation.coordinate.latitude)%7C\(userLocation.coordinate.longitude)&action=query&prop=coordinates%7Cpageimages%7Cpageterms&colimit=50&piprop=thumbnail&pithumbsize=500&pilimit=50&wbptterms=description&generator=geosearch&ggsradius=10000&ggslimit=50&format=json"
        
        guard let url = URL(string: urlString) else { return }
        
        if let data = try? Data(contentsOf: url) {
            sightsJSON = JSON(data)
            locationManager.startUpdatingHeading()
                //request user's heading
        }
    }
    
    func createSights() {
        
        //Loop over all returned wikipedia pages / sights (sent back as a dict)
        for page in sightsJSON["query"]["pagesDict"].dictionaryValue.values {
            
            //Pull out the coordinates of each pages  and set a CLLocation with them
            let locationLat = page["coordinates"][0]["lat"].doubleValue
            let locationLon = page["coordinates"][0]["lon"].doubleValue
            let location = CLLocation(latitude: locationLat, longitude: locationLon)
            
            
            //Calculate distance of user to pages location, then calculate it's  direction as well (the azimuth)
            let distance = Float(userLocation.distance(from: location))
            let azimuthFromUser = direction(from: userLocation, to: location)
            
            //Figure out the direction of the sight, using user's heading, convert direction to radians
            let angle = azimuthFromUser - userHeading
            let angleRadians = deg2rad(angle)
            
            //Create horizontal rotation matrix using direction radians
            let rotationHorizontal = simd_float4x4(SCNMatrix4MakeRotation(Float(angleRadians), 1, 0, 0))
            
            //Create vertical rotation matrix based on distance calc
            let rotationVertical = simd_float4x4(SCNMatrix4MakeRotation(-0.2 + Float(distance / 6000), 0, 1, 0))
            
            //Multiply hor and vert matrices, multiply result with ARKit camera transform
            let rotation = simd_mul(rotationHorizontal, rotationVertical)
            guard let sceneView = self.view as? ARSKView else { return }
            guard let frame = sceneView.session.currentFrame else { return }
            let rotation2 = simd_mul(frame.camera.transform, rotation)
            
            //Create identity matrix to position anchor into screen, relative to user distance of object, then multiply with combined matrix - rotation2
            var translation = matrix_identity_float4x4
            translation.columns.3.z = -(distance / 200)
            let transform = simd_mul(rotation2, translation)
            
            //Place anchor at new transform, then add entry to pagesDict
            let anchor = ARAnchor(transform: transform)
            sceneView.session.add(anchor: anchor)
            pagesDict[anchor.identifier] = page["title"].string ?? "Unknown"
            
        }
        
        
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        
        DispatchQueue.main.async {
            self.headingCount += 1
            
            if self.headingCount != 2 { return }
            self.userHeading = newHeading.magneticHeading
            
            self.locationManager.stopUpdatingHeading()
            self.createSights()
            
        }
    }
    
    //Degrees to radians
    func deg2rad(_ degrees: Double) -> Double {
        return degrees * .pi / 180
        
    }
    
    //Radians to degrees
    func rad2deg(_ degrees: Double) -> Double {
        return degrees * 180 / .pi
        
    }
    
    func direction(from p1: CLLocation, to p2: CLLocation) -> Double {
        
        let lat1 = deg2rad(p1.coordinate.latitude)
        let lon1 = deg2rad(p1.coordinate.longitude)
        
        let lat2 = deg2rad(p2.coordinate.latitude)
        let lon2 = deg2rad(p2.coordinate.longitude)
        
        let lon_delta = lon2 - lon1
        let y = sin(lon_delta) * cos(lon2)
        
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(lon_delta)
        
        let radians = atan2(y, x)
        return rad2deg(radians)
        
    }
    
}
