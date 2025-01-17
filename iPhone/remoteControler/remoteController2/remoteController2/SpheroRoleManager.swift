//
//  SpheroRoleManager.swift
//  remoteController2
//
//  Created by Valentin Gassant on 17/01/2025.
//

import Foundation
import UIKit
enum SpheroRole: String, CaseIterable {
    case maze = "maze"
    case handle1 = "Handle 1"
    case handle2 = "Handle 2"
    case handle3 = "Handle 3"
    case handle4 = "Handle 4"
    case unassigned = "Unassigned"
}
struct SpheroRoleAssignment {
    var spheroName: String
    var role: SpheroRole
    var toy: BoltToy?
}
class SpheroRoleManager: ObservableObject {
    @Published var roleAssignments: [SpheroRoleAssignment] = []
    private let wsClient: WebSocketClient
    static let instance = SpheroRoleManager(wsClient:WebSocketClient.instance)
    
    init(wsClient: WebSocketClient) {
        self.wsClient = wsClient
    }
    
    func autoAssignRoles() {
        let handleSpheros = ["SB-92B2","SB-F682"]
        let mazeSphero = "SB-5D1C"
        let roles: [SpheroRole] = [.handle3, .handle4]
        
        // First assign maze role if the Sphero is present
        let mazeToy = SharedToyBox.instance.bolts.first(where: { $0.peripheral?.name == mazeSphero })
        if mazeToy != nil {
            assignRole(to: mazeSphero, role: .maze, toy: mazeToy)
        }
        
        // Then assign handle roles to the other Spheros
        for (index, spheroName) in handleSpheros.enumerated() {
            if index < roles.count {
                let toy = SharedToyBox.instance.bolts.first(where: { $0.peripheral?.name == spheroName })
                assignRole(to: spheroName, role: roles[index], toy: toy)
            }
        }
    }
    
    func handleDisconnection(_ spheroName: String) {
        if let index = roleAssignments.firstIndex(where: { $0.spheroName == spheroName }) {
            roleAssignments.remove(at: index)
        }
    }
    
    func assignRole(to spheroName: String, role: SpheroRole, toy: BoltToy?) {
        print("Assigning role \(role.rawValue) to \(spheroName)")
        if let index = roleAssignments.firstIndex(where: { $0.spheroName == spheroName }) {
            if role != .unassigned {
                if let existingIndex = roleAssignments.firstIndex(where: { $0.role == role }) {
                    roleAssignments[existingIndex].role = .unassigned
                }
                
            }
            roleAssignments[index].role = role
        } else {
            roleAssignments.append(SpheroRoleAssignment(spheroName: spheroName, role: role, toy: toy))
        }
        if let sphero = toy {
            switch role {
            case .handle1, .handle2, .handle3, .handle4:
                sphero.setFrontLed(color: UIColor(red: 0/255, green: 0/255, blue: 0/255, alpha: 0.0))
                sphero.setBackLed(color: UIColor(red: 0/255, green: 0/255, blue: 0/255, alpha: 0.0))
                
            case .maze:
                // Configurer la LED en jaune
                sphero.setFrontLed(color: UIColor(red: 0/255, green: 0/255, blue: 0/255, alpha: 0.0))
                sphero.setBackLed(color: UIColor(red: 0/255, green: 0/255, blue: 0/255, alpha: 0.0))
                
                // Envoyer le motif d'éclair
//                SpheroPresetManager.shared.sendLightningPreset(to: sphero)
                
            default:
                break
            }
        }
        sendRoleAssignmentMessage(spheroName: spheroName, role: role)
    }
    
    private func sendRoleAssignmentMessage(spheroName: String, role: SpheroRole) {
        let routeOrigin = "maze_iphone"
        let routeTarget = ["maze_iphone"]
        let component = "sphero"
        let data = "\(role.rawValue.lowercased())"
        wsClient.sendMessage(from: routeOrigin, to: routeTarget, component: component, data: data)
    }
    
    func getRole(for spheroName: String) -> SpheroRole {
        return roleAssignments.first(where: { $0.spheroName == spheroName })?.role ?? .unassigned
    }
    
    func getRoleAssignment(for role: SpheroRole) -> SpheroRoleAssignment? {
        return roleAssignments.first(where: { $0.role == role })
    }
}
