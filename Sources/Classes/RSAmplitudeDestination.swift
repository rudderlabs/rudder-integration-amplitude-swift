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
    var amplitudeConfig: AmplitudeConfig?
        
    func update(serverConfig: RSServerConfig, type: UpdateType) {
        guard type == .initial else { return }
        if let amplitudeConfig: AmplitudeConfig = serverConfig.getConfig(forPlugin: self) {
            self.amplitudeConfig = amplitudeConfig
            
            Amplitude.instance().trackingSessionEvents = amplitudeConfig.trackSessionEvents
            Amplitude.instance().eventUploadPeriodSeconds = Int32(amplitudeConfig.eventUploadPeriodMillis / 1000)
            Amplitude.instance().eventUploadThreshold = Int32(amplitudeConfig.eventUploadThreshold)
            if amplitudeConfig.useIdfaAsDeviceId {
                Amplitude.instance().useAdvertisingIdForDeviceId()
            }
            Amplitude.instance().initializeApiKey(amplitudeConfig.apiKey)
        }
    }
    
    func identify(message: IdentifyMessage) -> IdentifyMessage? {
        guard let amplitudeConfig = amplitudeConfig else {
            return message
        }
        
        if let userId = message.userId, !userId.isEmpty {
            Amplitude.instance().setUserId(userId)
        }
        let identify = AMPIdentify()
        var outOfSession = false
        if let traits = message.traits {
            for (key, value) in traits {
                if key == "optOutOfSession" {
                    outOfSession = value as? Bool ?? false
                }
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
            return message
        }
        if !message.event.isEmpty {
//            let productList = extractProducts(from: message.properties)
//            if message.event == RSEvents.Ecommerce.orderCompleted {
//                if let properties = message.properties, let productList = productList {
//                    let outOfSession = properties["optOutOfSession"] as? Bool ?? false
//                    for product in productList {
//                        if amplitudeConfig.trackProductsOnce {
//                            Amplitude.instance().logEvent("Product Purchased", withEventProperties: product.dictionaryValue, outOfSession: outOfSession)
//                        } else {
//                            var properties = message.properties
//                            properties?.removeValue(forKey: RSKeys.Ecommerce.products)
//                            Amplitude.instance().logEvent("Product Purchased", withEventProperties: properties, outOfSession: outOfSession)
//                        }
//                    }
//                }
//            } else {
//                let outOfSession = message.properties?["optOutOfSession"] as? Bool ?? false
//                Amplitude.instance().logEvent(message.event, withEventProperties: message.properties, outOfSession: outOfSession)
//            }
//            if amplitudeConfig.trackRevenuePerProduct {
//                if let properties = message.properties, let productList = productList {
//                    var revenue: Double?
//                    if let revenueValue = properties[RSKeys.Ecommerce.revenue] as? Double {
//                        revenue = revenueValue
//                    } else if let revenueString = properties[RSKeys.Ecommerce.revenue] as? String, let revenueValue = Double(revenueString) {
//                        revenue = revenueValue
//                    } else if let revenueValue = properties[RSKeys.Ecommerce.revenue] as? Int {
//                        revenue = Double(revenueValue)
//                    }
//                    for product in productList {
//                        guard let revenue = revenue, var price = product.price else { return message }
//
//                        let amplitudeRevenue = AMPRevenue()
//
//                        if let quantity = product.quantity {
//                            amplitudeRevenue.setQuantity(quantity)
//                        } else {
//                            amplitudeRevenue.setQuantity(1)
//                        }
//
//                        if price == 0 {
//                            price = revenue
//                        }
//                        amplitudeRevenue.setPrice(price as NSNumber)
//
//                        if let revenueType = product.revenueType {
//                            amplitudeRevenue.setRevenueType(revenueType)
//                        } else if message.event == RSEvents.Ecommerce.orderCompleted {
//                            amplitudeRevenue.setRevenueType("Purchase")
//                        }
//
//                        if let productId = product.productId {
//                            amplitudeRevenue.setProductIdentifier(productId)
//                        }
//
//                        if let receiptObject = properties["receipt"], let receipt = try? NSKeyedArchiver.archivedData(withRootObject: receiptObject, requiringSecureCoding: true) {
//                            amplitudeRevenue.setReceipt(receipt)
//                        }
//
//                        Amplitude.instance().logRevenueV2(amplitudeRevenue)
//                    }
//                }
//            }
            
            if amplitudeConfig.trackProductsOnce {
                if let products = message.properties?["products"] as? [[String: Any]] {
                    logEventAndCorrespondingRevenue(message.properties, withEventName: message.event, withDoNotTrackRevenue: amplitudeConfig.trackRevenuePerProduct)
                    if (amplitudeConfig.trackRevenuePerProduct) {
                        trackingEventAndRevenuePerProduct(message.properties, withProductsArray: products, withTrackEventPerProduct: false)
                    }
                }
                logEventAndCorrespondingRevenue(message.properties, withEventName: message.event, withDoNotTrackRevenue: false)
                return message
            }
            if var properties = message.properties, let products = properties[RSKeys.Ecommerce.products] as? [[String: Any]] {
                properties.removeValue(forKey: RSKeys.Ecommerce.products)
                logEventAndCorrespondingRevenue(properties, withEventName: message.event, withDoNotTrackRevenue: amplitudeConfig.trackRevenuePerProduct)
                trackingEventAndRevenuePerProduct(properties, withProductsArray: products, withTrackEventPerProduct: true)
                return message
            }
            logEventAndCorrespondingRevenue(message.properties, withEventName: message.event, withDoNotTrackRevenue: false)
        }
        return message
    }
    
    func screen(message: ScreenMessage) -> ScreenMessage? {
        guard let amplitudeConfig = amplitudeConfig else {
            return message
        }
        if !message.name.isEmpty {
            if amplitudeConfig.trackAllPages {
                Amplitude.instance().logEvent("Viewed \(message.name) Screen", withEventProperties: message.properties)
            }
            if amplitudeConfig.trackNamedPages {
                Amplitude.instance().logEvent("Viewed \(message.name) Screen", withEventProperties: message.properties)
            }
            if amplitudeConfig.trackCategorizedPages {
                if let category = message.category {
                    Amplitude.instance().logEvent("Viewed \(category) Screen", withEventProperties: message.properties)
                }
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
    func extractProducts(from properties: [String: Any]?) -> [AmplitudeProduct]? {
        guard let properties = properties else {
            return nil
        }
        
        func handleProductData(productList: inout [AmplitudeProduct], product: [String: Any]) {
//            let revenueType = properties["revenue_type"] as? String
            var amplitudeProduct = AmplitudeProduct()
            for (key, value) in product {
                switch key {
                case RSKeys.Ecommerce.productId:
                    amplitudeProduct.productId = "\(value)"
                case RSKeys.Ecommerce.productName:
                    amplitudeProduct.name = "\(value)"
                case RSKeys.Ecommerce.category:
                    amplitudeProduct.category = "\(value)"
                case RSKeys.Ecommerce.quantity:
                    amplitudeProduct.quantity = Int("\(value)")
                case RSKeys.Ecommerce.price:
                    amplitudeProduct.price = Double("\(value)")
                case RSKeys.Ecommerce.sku:
                    amplitudeProduct.sku = "\(value)"
                default:
                    break
                }
//                amplitudeProduct.revenueType = revenueType
            }
            if !amplitudeProduct.isEmpty {
                productList.append(amplitudeProduct)
            }
        }
        var productList = [AmplitudeProduct]()
        if let products = properties[RSKeys.Ecommerce.products] as? [[String: Any]] {
            for product in products {
                handleProductData(productList: &productList, product: product)
            }
        } else {
            handleProductData(productList: &productList, product: properties)
        }
        if !productList.isEmpty {
            return productList
        }
        return nil
    }
    
    func logEventAndCorrespondingRevenue(_ properties: [String: Any]?, withEventName eventName: String, withDoNotTrackRevenue doNotTrackRevenue: Bool) {
        guard let properties = properties else {    // TODO: Check if ese block is called or not when property is nil
            Amplitude.instance().logEvent(eventName)
            return
        }
        if let optOutOfSession: Bool = properties["optOutOfSession"] as? Bool {
            Amplitude.instance().logEvent(eventName, withEventProperties: properties, outOfSession: optOutOfSession)
        }
        if (properties["revenue"] != nil && !doNotTrackRevenue) {
            trackRevenue(properties, withEventName: eventName)
        }
    }
    
    func trackingEventAndRevenuePerProduct(_ properties: [String: Any]?, withProductsArray products: [[String: Any]], withTrackEventPerProduct trackEventPerProduct: Bool) {
        guard let properties = properties else {
            return
        }
        let revenueType = properties["revenue_type"]
        for var product: [String: Any] in products {
            if let trackRevenuePerProduct: Bool = amplitudeConfig?.trackRevenuePerProduct, trackRevenuePerProduct == true {
                if (revenueType != nil) {
                    product["revenueType"] = revenueType
                }
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
            if let price = properties[RSKeys.Ecommerce.price] as? NSNumber{
                revenueDetail.price = price
            }
            if let productId = properties[RSKeys.Ecommerce.productId] as? String {
                revenueDetail.productId = productId
            }
            if let revenueType = properties["revenue_type"] as? String{
                revenueDetail.revenueType = revenueType
            }
            if let receiptObject = properties["receipt"], let receipt = try? NSKeyedArchiver.archivedData(withRootObject: receiptObject, requiringSecureCoding: true) {
                revenueDetail.receipt = receipt
            }
            return revenueDetail
        }
        
        let mapRevenueType = [
            "order completed" : "Purchase",
            "completed order" : "Purchase",
            "product purchased" : "Purchase"
        ]
        
        if let revenueDetail = getRevenueDetails(properties: properties) {
            if revenueDetail.revenue == nil && revenueDetail.price != nil {
                RSClient.sharedInstance().log(message: "revenue or price is not present.", logLevel: .debug)
                return
            }
            
            /// Default value of `Quantity` is set to 1 and `price` is set to 0
            var quantity: Int = revenueDetail.quantity ?? 1
            let revenueType: String? = revenueDetail.revenueType ?? mapRevenueType[eventName.lowercased()]
            var price: NSNumber = revenueDetail.price ?? 0
            if price == 0 {
                price = revenueDetail.revenue as? NSNumber ?? 0
                quantity = 1;
            }
            
            let amplitudeRevenue = AMPRevenue()
                .setPrice(price)
                .setQuantity(quantity)
                .setEventProperties(properties)
            
            if let revenueType = revenueType, !revenueType.isEmpty {
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
}

struct AmplitudeProduct {
    var productId: String?
    var name: String?
    var category: String?
    var quantity: Int?
    var price: Double?
    var sku: String?
    var revenueType: String?
    
    var dictionaryValue: [String: Any] {
        var properties = [String: Any]()
        if let productId = productId {
            properties[RSKeys.Ecommerce.productId] = productId
        }
        if let name = name {
            properties[RSKeys.Ecommerce.productName] = name
        }
        if let category = category {
            properties[RSKeys.Ecommerce.category] = category
        }
        if let quantity = quantity {
            properties[RSKeys.Ecommerce.quantity] = quantity
        }
        if let price = price {
            properties[RSKeys.Ecommerce.price] = price
        }
        if let sku = sku {
            properties[RSKeys.Ecommerce.sku ] = sku
        }
        if let revenueType = revenueType {
            properties["revenueType"] = revenueType
        }
        return properties
    }
    
    var isEmpty: Bool {
        return productId == nil && name == nil && category == nil && quantity == nil && price == nil && sku == nil && revenueType == nil
    }
}

struct AmplitudeConfig: Codable {
    
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
    
    private let _eventUploadPeriodMillis: Int?
    var eventUploadPeriodMillis: Int {
        return _eventUploadPeriodMillis ?? 0
    }
    
    private let _eventUploadThreshold: Int?
    var eventUploadThreshold: Int {
        return _eventUploadThreshold ?? 0
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
