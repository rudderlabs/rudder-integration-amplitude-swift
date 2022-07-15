//
//  AppDelegate.swift
//  ExampleSwift
//
//  Created by Arnab Pal on 09/05/20.
//  Copyright © 2020 RudderStack. All rights reserved.
//

import UIKit
import Rudder
import RudderAmplitude

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var client: RSClient?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        let config: RSConfig = RSConfig(writeKey: "1wvsoF3Kx2SczQNlx1dvcqW9ODW")
            .dataPlaneURL("https://rudderstacz.dataplane.rudderstack.com")
            .loglevel(.debug)
            .trackLifecycleEvents(true)
            .recordScreenViews(true)
        
        client = RSClient.sharedInstance()
        client?.configure(with: config)

        client?.addDestination(RudderAmplitudeDestination())
        sendEvents()
        
        return true
    }
    func sendEvents() {
        track()
        screen()
        RSClient.sharedInstance().reset()
        identify()
        func identify() {
            RSClient.sharedInstance().identify("UserId_1")
            RSClient.sharedInstance().track("UserId_TrackEvent_2")
            
            let traits: [String: Any] = [
                "optOutOfSession": true,
                "traits-1": "34",
                "traits-2": true,
                "traits-3": 456.78,
                "traits-4": "test@example.com",
                "key-1": "value-1"
            ]
            RSClient.sharedInstance().identify("UserId_3", traits: traits)
            RSClient.sharedInstance().track("UserId_TrackEvent_3")

            let traits: [String: Any] = [
                "key-1": "value-1"
            ]
            RSClient.sharedInstance().identify("UserId_4", traits: traits)
            RSClient.sharedInstance().track("UserId_TrackEvent_4")
        }
        func screen() {
            let properties: [String: Any] = [
                "key-1": "value-1",
                "category": "mobile"
            ]
            RSClient.sharedInstance().screen("Screen Event-3", category: "Apple", properties: properties)
        }
        func track() {
            let products: [String: Any] = [
                RSKeys.Ecommerce.productId: "1001",
                RSKeys.Ecommerce.productName: "Books-1",
                RSKeys.Ecommerce.category: "Books",
                RSKeys.Ecommerce.sku: "Books-sku",
                RSKeys.Ecommerce.quantity: 2,
                RSKeys.Ecommerce.price: 1203.2
            ]
            let fullPath = getDocumentsDirectory().appendingPathComponent("randomFilename")
            func getDocumentsDirectory() -> URL {
                let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                return paths[0]
            }
            let properties: [String: Any] = [
                RSKeys.Ecommerce.products: [products],
                "optOutOfSession": true,
                RSKeys.Ecommerce.revenue: 1203,
                RSKeys.Ecommerce.quantity: 10,
                RSKeys.Ecommerce.price: 101.34,
                RSKeys.Ecommerce.productId: "123",
                "revenue_type": "revenue_type_value",
                "receipt": fullPath
            ]
            // Track call with properties
            RSClient.sharedInstance().track("Event-9", properties: properties)
            
            // Track call without properties:
            RSClient.sharedInstance().track("Event-11")
        }
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}

extension UIApplicationDelegate {
    var client: RSClient? {
        if let appDelegate = self as? AppDelegate {
            return appDelegate.client
        }
        return nil
    }
}
