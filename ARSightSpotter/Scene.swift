//
//  Scene.swift
//  ARSightSpotter
//
//  Created by Simon Italia on 6/24/19.
//  Copyright © 2019 Magical Tomato. All rights reserved.
//

import SpriteKit
import ARKit

class Scene: SKScene {
    
    override func didMove(to view: SKView) {
        // Setup your scene here
    }
    
    override func update(_ currentTime: TimeInterval) {
        // Called before each frame is rendered
    }
    
    //Detect user touches
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        //Detect user screen touch
        guard let touch = touches.first else { return }
        
        //Detect positon of user touch
        let location = touch.location(in: self)
        
        //Detect if a node is at touched location
        let nodesTouched = nodes(at: location)
        
        //Remove label nodes touched by user with animation
        if let node = nodesTouched.first {
            
            //Set animation actions
            let scaleOut = SKAction.scale(to: 2, duration: 0.2)
            let fadeOut = SKAction.fadeOut(withDuration: 0.2)
            let group = SKAction.group([scaleOut, fadeOut])
            let sequence = SKAction.sequence([group, SKAction.removeFromParent()])
            
            //Run actions on applicable node, remove node from parent
            if node.name == "containerNode" {
                node.run(sequence)
            }
            
            if node.name == "childNode" {
                let parent = node.parent
                parent?.run(sequence)
            }
        }
    }
}
