//
//  RSAmplitudeDestination.swift
//  RudderAmplitude
//
//  Created by Pallab Maiti on 04/03/22.
//

import Foundation
import RudderStack
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
            let productList = extractProducts(from: message.properties)
            if message.event == RSECommerceConstants.ECommOrderCompleted {
                if let properties = message.properties, let productList = productList {
                    let outOfSession = properties["optOutOfSession"] as? Bool ?? false
                    for product in productList {
                        if amplitudeConfig.trackProductsOnce {
                            Amplitude.instance().logEvent("Product Purchased", withEventProperties: product.dictionaryValue, outOfSession: outOfSession)
                        } else {
                            var properties = message.properties
                            properties?.removeValue(forKey: "products")
                            Amplitude.instance().logEvent("Product Purchased", withEventProperties: properties, outOfSession: outOfSession)
                        }
                    }
                }
            } else {
                let outOfSession = message.properties?["optOutOfSession"] as? Bool ?? false
                Amplitude.instance().logEvent(message.event, withEventProperties: message.properties, outOfSession: outOfSession)
            }
            if amplitudeConfig.trackRevenuePerProduct {
                if let properties = message.properties, let productList = productList {
                    var revenue: Double?
                    if let revenueValue = properties["revenue"] as? Double {
                        revenue = revenueValue
                    } else if let revenueString = properties["revenue"] as? String, let revenueValue = Double(revenueString) {
                        revenue = revenueValue
                    } else if let revenueValue = properties["revenue"] as? Int {
                        revenue = Double(revenueValue)
                    }
                    for product in productList {
                        guard let revenue = revenue, var price = product.price else { return message }
                        
                        let amplitudeRevenue = AMPRevenue()
                        
                        if let quantity = product.quantity {
                            amplitudeRevenue.setQuantity(quantity)
                        } else {
                            amplitudeRevenue.setQuantity(1)
                        }
                        
                        if price == 0 {
                            price = revenue
                        }
                        amplitudeRevenue.setPrice(price as NSNumber)
                        
                        if let revenueType = product.revenueType {
                            amplitudeRevenue.setRevenueType(revenueType)
                        } else if message.event == RSECommerceConstants.ECommOrderCompleted {
                            amplitudeRevenue.setRevenueType("Purchase")
                        }
                        
                        if let productId = product.productId {
                            amplitudeRevenue.setProductIdentifier(productId)
                        }
                        
                        if let receiptObject = properties["receipt"], let receipt = try? NSKeyedArchiver.archivedData(withRootObject: receiptObject, requiringSecureCoding: true) {
                            amplitudeRevenue.setReceipt(receipt)
                        }
                        
                        Amplitude.instance().logRevenueV2(amplitudeRevenue)
                    }
                }
            }
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
            let revenueType = properties["revenue_type"] as? String
            var amplitudeProduct = AmplitudeProduct()
            for (key, value) in product {
                switch key {
                case "product_id":
                    amplitudeProduct.productId = "\(value)"
                case "name":
                    amplitudeProduct.name = "\(value)"
                case "category":
                    amplitudeProduct.category = "\(value)"
                case "quantity":
                    amplitudeProduct.quantity = Int("\(value)")
                case "price":
                    amplitudeProduct.price = Double("\(value)")
                case "sku":
                    amplitudeProduct.sku = "\(value)"
                default:
                    break
                }
                amplitudeProduct.revenueType = revenueType
            }
            if !amplitudeProduct.isEmpty {
                productList.append(amplitudeProduct)
            }
        }
        var productList = [AmplitudeProduct]()
        if let products = properties["products"] as? [[String: Any]] {
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
            properties["productId"] = productId
        }
        if let name = name {
            properties["name"] = name
        }
        if let category = category {
            properties["category"] = category
        }
        if let quantity = quantity {
            properties["quantity"] = quantity
        }
        if let price = price {
            properties["price"] = price
        }
        if let sku = sku {
            properties["sku"] = sku
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
