<p align="center">
  <a href="https://rudderstack.com/">
    <img src="https://user-images.githubusercontent.com/59817155/121357083-1c571300-c94f-11eb-8cc7-ce6df13855c9.png">
  </a>
</p>

<p align="center"><b>The Customer Data Platform for Developers</b></p>

<p align="center">
  <a href="https://cocoapods.org/pods/RudderAmplitude">
    <img src="https://img.shields.io/cocoapods/v/RudderAmplitude.svg?style=flat">
    </a>
</p>

<p align="center">
  <b>
    <a href="https://rudderstack.com">Website</a>
    ·
    <a href="https://rudderstack.com/docs/stream-sources/rudderstack-sdk-integration-guides/rudderstack-swift-sdk/">Documentation</a>
    ·
    <a href="https://rudderstack.com/join-rudderstack-slack-community">Community Slack</a>
  </b>
</p>

---
# Integrating RudderStack iOS SDK with Amplitude

This repository contains the resources and assets required to integrate the [RudderStack iOS SDK](https://www.rudderstack.com/docs/stream-sources/rudderstack-sdk-integration-guides/rudderstack-ios-sdk/) with [Amplitude](https://www.amplitude.com/).

| For more information on configuring Amplitude as a destination in RudderStack and the supported events and their mappings, refer to the [Amplitude documentation](https://www.rudderstack.com/docs/destinations/analytics/amplitude/).   |
| :--|


## Step 1: Integrate the SDK with Amplitude

1. Add [Amplitude](https://www.amplitude.com/) as a destination in the [RudderStack dashboard](https://app.rudderstack.com/).
2. `RudderAmplitude` is available through [CocoaPods](https://cocoapods.org). To install it, add the following line to your Podfile and followed by `pod install`, as shown:

```ruby
pod 'RudderAmplitude'
```

## Step 2: Initialize the RudderStack client (`RSClient`)

Place the following in your ```AppDelegate``` under the ```didFinishLaunchingWithOptions``` method:

### Objective C

```objective-c
RSConfig *config = [[RSConfig alloc] initWithWriteKey:WRITE_KEY];
[config dataPlaneURL:DATA_PLANE_URL];
[[RSClient sharedInstance] configureWith:config];
[[RSClient sharedInstance] addDestination:[[RudderAmplitudeDestination alloc] init]];
```
### Swift

```swift
let config: RSConfig = RSConfig(writeKey: WRITE_KEY)
            .dataPlaneURL(DATA_PLANE_URL)
RSClient.sharedInstance().configure(with: config)
RSClient.sharedInstance().addDestination(RudderAmplitudeDestination())
```

## Step 3: Send events

Follow the steps listed in the [RudderStack Swift SDK](https://github.com/rudderlabs/rudder-sdk-ios/tree/master-v2#sending-events) repo to start sending events to Amplitude.

## About RudderStack

RudderStack is the **customer data platform** for developers. With RudderStack, you can build and deploy efficient pipelines that collect customer data from every app, website, and SaaS platform, then activate your data in your warehouse, business, and marketing tools.

| Start building a better, warehouse-first CDP that delivers complete, unified data to every part of your customer data stack. Sign up for [RudderStack Cloud](https://app.rudderstack.com/signup?type=freetrial) today. |
| :---|

## Contact us

For queries on configuring or using this integration, [contact us](mailto:%20docs@rudderstack.com) or start a conversation in our [Slack](https://rudderstack.com/join-rudderstack-slack-community) community.
