//
//  RSAmplitudeDestination.swift
//  RudderAmplitude
//
//  Created by Pallab Maiti on 04/03/22.
//

import Foundation
import Rudder
import Amplitude

class RSAmplitudeDestination: RSDestinationPlugin {
    let type = PluginType.destination
    let key = "Amplitude"
    var client: RSClient?
    var controller = RSController()
    var amplitudeConfig: RudderAmplitudeConfig?
        
    func update(serverConfig: RSServerConfig, type: UpdateType) {
        guard type == .initial else { return }
        guard let amplitudeConfig: RudderAmplitudeConfig = serverConfig.getConfig(forPlugin: self) else {
            client?.log(message: "Failed to Initialize Amplitude Factory", logLevel: .warning)
            return
        }
        
        self.amplitudeConfig = amplitudeConfig
        Amplitude.instance().trackingSessionEvents = amplitudeConfig.trackSessionEvents
        Amplitude.instance().eventUploadPeriodSeconds = Int32(amplitudeConfig.eventUploadPeriodMillis / 1000)
        Amplitude.instance().eventUploadThreshold = Int32(amplitudeConfig.eventUploadThreshold)
        if amplitudeConfig.useIdfaAsDeviceId {
            Amplitude.instance().useAdvertisingIdForDeviceId()
        }
        Amplitude.instance().initializeApiKey(amplitudeConfig.apiKey)
        client?.log(message: "Initializing Amplitude SDK.", logLevel: .debug)
    }
    
    func identify(message: IdentifyMessage) -> IdentifyMessage? {
        guard let amplitudeConfig = amplitudeConfig else {
            client?.log(message: "Amplitude instance is not initialised", logLevel: .warning)
            return message
        }
        
        if let userId = message.userId, !userId.isEmpty {
            Amplitude.instance().setUserId(userId)
        }
        let identify = AMPIdentify()
        let outOfSession = message.traits?["optOutOfSession"] as? Bool ?? false
        if let traits = message.traits {
            for (key, value) in traits {
                if let traitsToIncrement = amplitudeConfig.traitsToIncrement, traitsToIncrement.contains(key) {
                    identify.add(key, value: value as? NSObject)
                    continue
                }
                if let traitsToSetOnce = amplitudeConfig.traitsToSetOnce, traitsToSetOnce.contains(key) {
                    identify.setOnce(key, value: value as? NSObject)
                    continue
                }
                if let traitsToAppend = amplitudeConfig.traitsToAppend, traitsToAppend.contains(key) {
                    identify.append(key, value: value as? NSObject)
                    continue
                }
                if let traitsToPrepend = amplitudeConfig.traitsToPrepend, traitsToPrepend.contains(key) {
                    identify.prepend(key, value: value as? NSObject)
                    continue
                }
                
                identify.set(key, value: value as? NSObject)
            }
        }
        Amplitude.instance().identify(identify, outOfSession: outOfSession)
        return message
    }
    
    func track(message: TrackMessage) -> TrackMessage? {
        guard let amplitudeConfig = amplitudeConfig else {
            client?.log(message: "Amplitude config is not initalised properly, hence dropping track events.", logLevel: .warning)
            return message
        }
        if !message.event.isEmpty {
            /// If `trackProductsOnce` is enabled
            if amplitudeConfig.trackProductsOnce {
                if var properties = message.properties, let products = extractProducts(from: message.properties) {
                    properties[RSKeys.Ecommerce.products] = products
                    logEventAndCorrespondingRevenue(properties, withEventName: message.event, withDoNotTrackRevenue: amplitudeConfig.trackRevenuePerProduct)
                    /// If `trackRevenuePerProduct` is enabled
                    if amplitudeConfig.trackRevenuePerProduct {
                        trackingEventAndRevenuePerProduct(properties, withProductsArray: products, withTrackEventPerProduct: false)
                    }
                    return message
                }
                logEventAndCorrespondingRevenue(message.properties, withEventName: message.event, withDoNotTrackRevenue: false)
                return message
            }
            /// If `products array` is present in the properties
            if var properties = message.properties, let products = extractProducts(from: message.properties) {
                properties.removeValue(forKey: RSKeys.Ecommerce.products)
                logEventAndCorrespondingRevenue(properties, withEventName: message.event, withDoNotTrackRevenue: amplitudeConfig.trackRevenuePerProduct)
                trackingEventAndRevenuePerProduct(properties, withProductsArray: products, withTrackEventPerProduct: true)
                return message
            }
            // Default case
            logEventAndCorrespondingRevenue(message.properties, withEventName: message.event, withDoNotTrackRevenue: false)
        }
        return message
    }
    
    func screen(message: ScreenMessage) -> ScreenMessage? {
        guard let amplitudeConfig = amplitudeConfig else {
            client?.log(message: "Amplitude config is not initalised properly, hence dropping screen events.", logLevel: .warning)
            return message
        }
        
        if !message.name.isEmpty {
            if amplitudeConfig.trackAllPages {
                Amplitude.instance().logEvent("Viewed \(message.name) Screen", withEventProperties: message.properties, outOfSession: false)
            }
            if amplitudeConfig.trackNamedPages {
                Amplitude.instance().logEvent("Viewed \(message.name) Screen", withEventProperties: message.properties, outOfSession: false)
            }
        }
        if amplitudeConfig.trackCategorizedPages {
            if let category = message.category, !category.isEmpty {
                Amplitude.instance().logEvent("Viewed \(category) Screen", withEventProperties: message.properties, outOfSession: false)
            }
        }
        return message
    }
    
    func reset() {
        Amplitude.instance().setUserId(nil)
        Amplitude.instance().regenerateDeviceId()
    }
    
    func flush() {
        Amplitude.instance().uploadEvents()
    }
}

// MARK: - Support methods

extension RSAmplitudeDestination {
    func extractProducts(from properties: [String: Any]?) -> [[String: Any]]? {
        guard let properties = properties else {
            return nil
        }
        
        func handleProductData(productList: inout [[String: Any]], product: [String: Any]) {
            var amplitudeProduct = [String: Any]()
            for (key, value) in product {
                switch key {
                case RSKeys.Ecommerce.productId, RSKeys.Ecommerce.productName, RSKeys.Ecommerce.category, RSKeys.Ecommerce.sku:
                    amplitudeProduct[key] = "\(value)"
                case RSKeys.Ecommerce.quantity:
                    amplitudeProduct[key] = Int("\(value)")
                case RSKeys.Ecommerce.price:
                    amplitudeProduct[key] = Double("\(value)")
                default:
                    break
                }
            }
            if !amplitudeProduct.isEmpty {
                productList.append(amplitudeProduct)
            }
        }
        var productList = [[String: Any]]()
        if let products = properties[RSKeys.Ecommerce.products] as? [[String: Any]] {
            for product in products {
                handleProductData(productList: &productList, product: product)
            }
            if !productList.isEmpty {
                return productList
            }
        }
        return nil
    }
    
    func logEventAndCorrespondingRevenue(_ properties: [String: Any]?, withEventName event: String, withDoNotTrackRevenue doNotTrackRevenue: Bool) {
        guard let properties = properties else {
            Amplitude.instance().logEvent(event)
            return
        }
        if let optOutOfSession: Bool = properties["optOutOfSession"] as? Bool {
            Amplitude.instance().logEvent(event, withEventProperties: properties, outOfSession: optOutOfSession)
        }
        if !doNotTrackRevenue {
            if properties[RSKeys.Ecommerce.revenue] == nil {
                client?.log(message: "Dropping trackRevenue method call, as Revenue parameter is not present in the properties.", logLevel: .debug)
                return
            }
            trackRevenue(properties, withEventName: event)
        }
    }
    
    func trackingEventAndRevenuePerProduct(_ properties: [String: Any]?, withProductsArray products: [[String: Any]], withTrackEventPerProduct trackEventPerProduct: Bool) {
        guard let properties = properties else {
            return
        }

        for var product: [String: Any] in products {
            if amplitudeConfig?.trackRevenuePerProduct == true {
                if product[RSKeys.Ecommerce.price] == nil {
                    client?.log(message: "Dropping trackRevenue method call, as Price parameter is not present in the products array", logLevel: .debug)
                    continue
                }
                if properties["revenue_type"] != nil {
                    product["revenueType"] = properties["revenue_type"]
                }
                /// `Price` parameter needs to be present in the products array
                trackRevenue(product, withEventName: "Product Purchased")
            }
            if trackEventPerProduct {
                logEventAndCorrespondingRevenue(product, withEventName: "Product Purchased", withDoNotTrackRevenue: true)
            }
        }
    }
    
    func trackRevenue(_ properties: [String: Any]?, withEventName eventName: String) {
        guard let properties = properties else {
            return
        }
        
        func getRevenueDetails(properties: [String: Any]?) -> RevenueProduct? {
            guard let properties = properties else {
                return nil
            }
            
            var revenueDetail = RevenueProduct()
            if let quantity = properties[RSKeys.Ecommerce.quantity] as? Int {
                revenueDetail.quantity = quantity
            }
            if let revenue = properties[RSKeys.Ecommerce.revenue] as? Double {
                revenueDetail.revenue = revenue
            }
            if let price = properties[RSKeys.Ecommerce.price] as? NSNumber {
                revenueDetail.price = price
            }
            if let productId = properties[RSKeys.Ecommerce.productId] as? String {
                revenueDetail.productId = productId
            }
            if let revenueType = properties["revenue_type"] as? String {
                revenueDetail.revenueType = revenueType
            }
            /// `receipt` type is url. Reference: https://www.hackingwithswift.com/example-code/system/how-to-save-and-load-objects-with-nskeyedarchiver-and-nskeyedunarchiver
            if let receiptObject = properties["receipt"] as? URL,
                let receipt = try? NSKeyedArchiver.archivedData(withRootObject: receiptObject, requiringSecureCoding: true) {
                revenueDetail.receipt = receipt
            }
            return revenueDetail
        }
        
        let mapRevenueType = [
            "order completed": "Purchase",
            "completed order": "Purchase",
            "product purchased": "Purchase"
        ]
        
        if let revenueDetail = getRevenueDetails(properties: properties), !revenueDetail.isEmpty {
            /// Default value of `Quantity` is set to 1 and `price` is set to 0
            var quantity: Int = revenueDetail.quantity ?? 1
            // Handle Price:
            var price: NSNumber = revenueDetail.price ?? 0
            if price == 0 {
                price = revenueDetail.revenue as? NSNumber ?? 0
                quantity = 1
            }
            
            let amplitudeRevenue = AMPRevenue()
                .setPrice(price)
                .setQuantity(quantity)
                .setEventProperties(properties)
            
            if let revenueType = revenueDetail.revenueType ?? mapRevenueType[eventName.lowercased()], !revenueType.isEmpty {
                amplitudeRevenue?.setRevenueType(revenueType)
            }
            if let productId = revenueDetail.productId, !productId.isEmpty {
                amplitudeRevenue?.setProductIdentifier(productId)
            }
            if let receipt = revenueDetail.receipt {
                amplitudeRevenue?.setReceipt(receipt)
            }
            
            if let amplitudeRevenue = amplitudeRevenue {
                Amplitude.instance().logRevenueV2(amplitudeRevenue)
            }
        }
    }
}

struct RevenueProduct {
    var quantity: Int?
    var revenue: Double?
    var price: NSNumber?
    var productId: String?
    var revenueType: String?
    var receipt: Data?
    
    var isEmpty: Bool {
        return quantity == nil && revenue == nil && price == nil && productId == nil && revenueType == nil
    }
}

struct RudderAmplitudeConfig: Codable {
    
    struct Traits: Codable {
        private let _traits: String?
        var traits: String {
            return _traits ?? ""
        }
        
        enum CodingKeys: String, CodingKey {
            case _traits = "traits"
        }
    }
    
    private let _apiKey: String?
    var apiKey: String {
        return _apiKey ?? ""
    }
    
    private let _groupTypeTrait: String?
    var groupTypeTrait: String {
        return _groupTypeTrait ?? ""
    }
    
    private let _groupValueTrait: String?
    var groupValueTrait: String {
        return _groupValueTrait ?? ""
    }
    
    private let _trackAllPages: Bool?
    var trackAllPages: Bool {
        return _trackAllPages ?? false
    }
    
    private let _trackCategorizedPages: Bool?
    var trackCategorizedPages: Bool {
        return _trackCategorizedPages ?? false
    }
    
    private let _trackNamedPages: Bool?
    var trackNamedPages: Bool {
        return _trackNamedPages ?? false
    }
    
    private let _trackProductsOnce: Bool?
    var trackProductsOnce: Bool {
        return _trackProductsOnce ?? false
    }
    
    private let _trackRevenuePerProduct: Bool?
    var trackRevenuePerProduct: Bool {
        return _trackRevenuePerProduct ?? false
    }
    
    private let _trackSessionEvents: Bool?
    var trackSessionEvents: Bool {
        return _trackSessionEvents ?? false
    }
    
    private let _eventUploadPeriodMillis: String?
    var eventUploadPeriodMillis: Int {
        return Int(_eventUploadPeriodMillis ?? "") ?? 0
    }
    
    private let _eventUploadThreshold: String?
    var eventUploadThreshold: Int {
        return Int(_eventUploadThreshold ?? "") ?? 0
    }
    
    private let _versionName: String?
    var versionName: String {
        return _versionName ?? ""
    }
    
    private let _useIdfaAsDeviceId: Bool?
    var useIdfaAsDeviceId: Bool {
        return _useIdfaAsDeviceId ?? false
    }
    
    private let _mapDeviceBrand: Bool?
    var mapDeviceBrand: Bool {
        return _mapDeviceBrand ?? false
    }
    
    private let _traitsToIncrement: [Traits]?
    var traitsToIncrement: [String]? {
        _traitsToIncrement?.compactMap({ traits in
            return traits.traits
        })
    }
    
    private let _traitsToSetOnce: [Traits]?
    var traitsToSetOnce: [String]? {
        _traitsToSetOnce?.compactMap({ traits in
            return traits.traits
        })
    }
    
    private let _traitsToAppend: [Traits]?
    var traitsToAppend: [String]? {
        _traitsToAppend?.compactMap({ traits in
            return traits.traits
        })
    }
    
    private let _traitsToPrepend: [Traits]?
    var traitsToPrepend: [String]? {
        _traitsToPrepend?.compactMap({ traits in
            return traits.traits
        })
    }
    
    enum CodingKeys: String, CodingKey {
        case _groupTypeTrait = "groupTypeTrait"
        case _apiKey = "apiKey"
        case _groupValueTrait = "groupValueTrait"
        case _trackAllPages = "trackAllPages"
        case _trackCategorizedPages = "trackCategorizedPages"
        case _trackNamedPages = "trackNamedPages"
        case _trackProductsOnce = "trackProductsOnce"
        case _trackRevenuePerProduct = "trackRevenuePerProduct"
        case _trackSessionEvents = "trackSessionEvents"
        case _traitsToIncrement = "traitsToIncrement"
        case _traitsToSetOnce = "traitsToSetOnce"
        case _traitsToAppend = "traitsToAppend"
        case _traitsToPrepend = "traitsToPrepend"
        case _eventUploadPeriodMillis = "eventUploadPeriodMillis"
        case _eventUploadThreshold = "eventUploadThreshold"
        case _versionName = "versionName"
        case _useIdfaAsDeviceId = "useIdfaAsDeviceId"
        case _mapDeviceBrand = "mapDeviceBrand"
    }
}

@objc
public class RudderAmplitudeDestination: RudderDestination {
    
    public override init() {
        super.init()
        plugin = RSAmplitudeDestination()
    }
    
}
