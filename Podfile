source 'https://github.com/CocoaPods/Specs.git'
workspace 'RudderAmplitude.xcworkspace'
use_frameworks!
inhibit_all_warnings!
platform :ios, '13.0'

def shared_pods
    pod 'Rudder', '~> 2.0.0'
end

target 'RudderAmplitude' do
    project 'RudderAmplitude.xcodeproj'
    shared_pods
    pod 'Amplitude', '8.8.0'
end

target 'SampleAppObjC' do
    project 'Examples/SampleAppObjC/SampleAppObjC.xcodeproj'
    shared_pods
    pod 'RudderAmplitude', :path => '.'
end

target 'SampleAppSwift' do
    project 'Examples/SampleAppSwift/SampleAppSwift.xcodeproj'
    shared_pods
    pod 'RudderAmplitude', :path => '.'
end
