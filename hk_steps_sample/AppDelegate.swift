//
//  AppDelegate.swift
//  hk_steps_sample
//
//  Created by Rick  Kystianne Lim on 1/6/21.
//

import UIKit
import HealthKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        if HKHealthStore.isHealthDataAvailable() {
            print("HKHealthStore available")
            // Add code to use HealthKit here.
            let healthStore = HKHealthStore()
        
            guard let stepCountType = HKObjectType.quantityType(
                forIdentifier: .stepCount
            ) else {
                fatalError("*** Unable to get the step count type ***")
            }
            
            guard let distanceType = HKObjectType.quantityType(
                forIdentifier: .distanceWalkingRunning
            ) else {
                fatalError("*** Unable to get the step count type ***")
            }
            
            healthStore.requestAuthorization(
                toShare: [],
                read: Set([stepCountType, distanceType])
            ) { (success, error) in
                if success {
                    print("Authorization OK")
                    
                    self.healthKitQuery(
                        dates: ["2020-07-06", "2021-01-07"],
                        healthStore: healthStore,
                        quantityType: stepCountType,
                        unit: HKUnit.count()
                    )
                    self.healthKitQuery(
                        dates: ["2020-07-06", "2021-01-07"],
                        healthStore: healthStore,
                        quantityType: distanceType,
                        unit: HKUnit.meter()
                    )
                } else {
                    print("Authorization failed")
                }
            }
        } else {
            print("HKHealthStore NOT available")
        }

        return true
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
    
    private func healthKitQuery(
        dates: Array<String>,
        healthStore: HKHealthStore,
        quantityType: HKQuantityType,
        unit: HKUnit
    ) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        dateFormatter.timeZone = TimeZone.current
        dateFormatter.locale = Locale.current
        
        let dateKeyFormatter = DateFormatter()
        dateKeyFormatter.dateFormat = "yyyy-MM-dd"
        dateKeyFormatter.timeZone = TimeZone.current
        dateKeyFormatter.locale = Locale.current
        
        let startDate = dateFormatter.date(
            from: "\(dates[0])T00:00:00"
        )!
        let anchorDate = dateFormatter.date(
            from: "\(dates[1])T23:59:59"
        )!
        
        var interval = DateComponents()
        interval.day = 1
        
        let datePredicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: anchorDate
        )
        let sourcesQuery = HKSourceQuery.init(
            sampleType: quantityType,
            samplePredicate: datePredicate
        ) { (query, sources, error) in
            sources?.forEach({ (shit) in
                print("shit = \(shit.bundleIdentifier)")
            })
            
            let filteredSources = sources?.filter({
                $0.bundleIdentifier.lowercased().hasPrefix("com.apple.health")
            })
            
//            if filteredSources == nil {
//                return
//            } else if filteredSources!.isEmpty {
//                print("NO DATA! DONE...")
//                return
//            }
            
            // Only calculate HealthKit data whose not from
            // "com.apple.Health" app. (Manually inputted)
            let sourcesPredicate = HKQuery.predicateForObjects(
                from: filteredSources!
            )
            let wasUserEnteredPredicate = HKQuery.predicateForObjects(
                withMetadataKey: HKMetadataKeyWasUserEntered,
                operatorType: .notEqualTo,
                value: 1
            )
            let predicate = NSCompoundPredicate.init(
                andPredicateWithSubpredicates: [
                    datePredicate,
//                    sourcesPredicate,
                    wasUserEnteredPredicate
                ]
            )
            let query = HKStatisticsCollectionQuery.init(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: anchorDate,
                intervalComponents: interval
            )
                
            query.initialResultsHandler = {
                query,
                results,
                error in

                var data = [String]()

                results?.enumerateStatistics(
                    from: startDate,
                    to: anchorDate,
                    with: { (queryResult, stop) in
                        let value = queryResult.sumQuantity()?.doubleValue(for: unit) ?? 0

                        if value > 0 {
                            data.append("\(dateKeyFormatter.string(from: queryResult.startDate.addingTimeInterval(24 * 60 * 60))),\(value)")
                        }

                        if (queryResult.startDate.compare(anchorDate) == ComparisonResult.orderedSame) {
                            print(data)
                            print("DONE!")
                        }
                    }
                )
            }
            
            healthStore.execute(query)
        }
        
        healthStore.execute(sourcesQuery)
    }


}

