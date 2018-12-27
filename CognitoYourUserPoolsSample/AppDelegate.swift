//
// Copyright 2014-2018 Amazon.com,
// Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Amazon Software License (the "License").
// You may not use this file except in compliance with the
// License. A copy of the License is located at
//
//     http://aws.amazon.com/asl/
//
// or in the "license" file accompanying this file. This file is
// distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, express or implied. See the License
// for the specific language governing permissions and
// limitations under the License.
//

import UIKit
import AWSCore
import AWSCognitoIdentityProvider
import AWSSNS
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    var signInViewController: SignInViewController?
    var mfaViewController: MFAViewController?
    var navigationController: UINavigationController?
    var storyboard: UIStoryboard?
    var rememberDeviceCompletionSource: AWSTaskCompletionSource<NSNumber>?
    
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        // ユーザーからPush Nortification通知の許可をもらう.
        if #available(iOS 10.0, *) {
            // iOS 10 以降の設定
            let notificationCenter = UNUserNotificationCenter.current()
            
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            notificationCenter.requestAuthorization(
                options: authOptions,
                completionHandler: {granted, error in
                    if error != nil {
                        // エラー時の処理
                        return
                    }
                    if granted {
                        // デバイストークンの要求
                        DispatchQueue.main.async(execute: {
                            UIApplication.shared.registerForRemoteNotifications()
                        })
                    }
            })
            
        } else {
            // iOS 10 より前の設定
            let settings: UIUserNotificationSettings =
                UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
            application.registerUserNotificationSettings(settings)
            UIApplication.shared.registerForRemoteNotifications()
            
        }
        
        // Warn user if configuration not updated
        if (CognitoIdentityUserPoolId == "ap-northeast-1_uOY42L9KD") {
            let alertController = UIAlertController(title: "Invalid Configuration",
                                                    message: "Please configure user pool constants in Constants.swift file.",
                                                    preferredStyle: .alert)
            let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
            alertController.addAction(okAction)
            
            self.window?.rootViewController!.present(alertController, animated: true, completion:  nil)
        }
        
        // setup logging
        AWSDDLog.sharedInstance.logLevel = .verbose
        
        // setup service configuration
        let serviceConfiguration = AWSServiceConfiguration(region: CognitoIdentityUserPoolRegion, credentialsProvider: nil)
        
        // create pool configuration
        let poolConfiguration = AWSCognitoIdentityUserPoolConfiguration(clientId: CognitoIdentityUserPoolAppClientId,
                                                                        clientSecret: CognitoIdentityUserPoolAppClientSecret,
                                                                        poolId: CognitoIdentityUserPoolId)
        
        // initialize user pool client
        AWSCognitoIdentityUserPool.register(with: serviceConfiguration, userPoolConfiguration: poolConfiguration, forKey: AWSCognitoUserPoolsSignInProviderKey)
        
        // fetch the user pool client we initialized in above step
        let pool = AWSCognitoIdentityUserPool(forKey: AWSCognitoUserPoolsSignInProviderKey)
        self.storyboard = UIStoryboard(name: "Main", bundle: nil)
        pool.delegate = self
        
        return true
    }
    
    // プッシュ通知の許可をユーザーからもらったら、トークンをSNSへ送信するコード
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        //Tokenの文字成形
        var token = String(format: "%@", deviceToken as CVarArg) as String
        let characterSet: CharacterSet = CharacterSet.init(charactersIn: "<>")
        token = token.trimmingCharacters(in: characterSet)
        token = token.replacingOccurrences(of: " ", with: "")
        print("deviceToken: \(token)")
        
        // Initialize the Amazon Cognito credentials provider
        let credentialsProvider = AWSCognitoCredentialsProvider(regionType:.APNortheast1,
                                                                identityPoolId:"ap-northeast-1:0b87cb12-8ca5-431b-9866-b964b04f65a2")
        let configuration = AWSServiceConfiguration(region:.APNortheast1, credentialsProvider:credentialsProvider)
        AWSServiceManager.default().defaultServiceConfiguration = configuration
        
        let sns = AWSSNS.default()
        let request = AWSSNSCreatePlatformEndpointInput()
        request?.token = token
        request?.platformApplicationArn = "arn:aws:sns:ap-northeast-1:792705657504:app/APNS_SANDBOX/MotionCaptureAppPushNortification"
        request?.customUserData = "Memo"
        
        sns.createPlatformEndpoint(request!).continueWith(executor: AWSExecutor.mainThread(), block: { (task: AWSTask!) -> AnyObject? in
            if task.error != nil {
                print("Error: \(String(describing: task.error))")
            } else {
                let result = task.result!
                let subscribeInput = AWSSNSSubscribeInput()
                subscribeInput?.topicArn = "arn:aws:sns:ap-northeast-1:792705657504:app/APNS_SANDBOX/MotionCaptureAppPushNortification"
                subscribeInput?.endpoint = result.endpointArn
                subscribeInput?.protocols = "Application"
                sns.subscribe(subscribeInput!)
                
                //self.saveEndpointArn(result.endpointArn)
            }
            return nil
        })
    }
    
    private func application(application: UIApplication!, didFailToRegisterForRemoteNotificationsWithError error: NSError!) {
        // プッシュ通知が利用不可であればerrorが返ってくる
        NSLog("error: " + "\(String(describing: error))")
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:
    }
    
}

// MARK:- AWSSNSDelegate protocol delegate
// プッシュ通知受信時のコードを追加
@available(iOS 10, *)
extension AppDelegate : UNUserNotificationCenterDelegate {
    
    // iOS 10 以降では通知を受け取るとこちらのデリゲートメソッドが呼ばれる。
    //foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("notification is \(notification)")
        //write your action here
        completionHandler(UNNotificationPresentationOptions.alert)
    }
    
    //background
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        print("response is \(response)")
        //write your action here
        completionHandler()
    }
}

// MARK:- AWSCognitoIdentityInteractiveAuthenticationDelegate protocol delegate

extension AppDelegate: AWSCognitoIdentityInteractiveAuthenticationDelegate {
    
    func startPasswordAuthentication() -> AWSCognitoIdentityPasswordAuthentication {
        if (self.navigationController == nil) {
            self.navigationController = self.storyboard?.instantiateViewController(withIdentifier: "signinController") as? UINavigationController
        }
        
        if (self.signInViewController == nil) {
            self.signInViewController = self.navigationController?.viewControllers[0] as? SignInViewController
        }
        
        DispatchQueue.main.async {
            self.navigationController!.popToRootViewController(animated: true)
            if (!self.navigationController!.isViewLoaded
                || self.navigationController!.view.window == nil) {
                self.window?.rootViewController?.present(self.navigationController!,
                                                         animated: true,
                                                         completion: nil)
            }
            
        }
        return self.signInViewController!
    }
    
    func startMultiFactorAuthentication() -> AWSCognitoIdentityMultiFactorAuthentication {
        if (self.mfaViewController == nil) {
            self.mfaViewController = MFAViewController()
            self.mfaViewController?.modalPresentationStyle = .popover
        }
        DispatchQueue.main.async {
            if (!self.mfaViewController!.isViewLoaded
                || self.mfaViewController!.view.window == nil) {
                //display mfa as popover on current view controller
                let viewController = self.window?.rootViewController!
                viewController?.present(self.mfaViewController!,
                                        animated: true,
                                        completion: nil)
                
                // configure popover vc
                let presentationController = self.mfaViewController!.popoverPresentationController
                presentationController?.permittedArrowDirections = UIPopoverArrowDirection.left
                presentationController?.sourceView = viewController!.view
                presentationController?.sourceRect = viewController!.view.bounds
            }
        }
        return self.mfaViewController!
    }
    
    func startRememberDevice() -> AWSCognitoIdentityRememberDevice {
        return self
    }
}

// MARK:- AWSCognitoIdentityRememberDevice protocol delegate

extension AppDelegate: AWSCognitoIdentityRememberDevice {
    
    func getRememberDevice(_ rememberDeviceCompletionSource: AWSTaskCompletionSource<NSNumber>) {
        self.rememberDeviceCompletionSource = rememberDeviceCompletionSource
        DispatchQueue.main.async {
            // dismiss the view controller being present before asking to remember device
            self.window?.rootViewController!.presentedViewController?.dismiss(animated: true, completion: nil)
            let alertController = UIAlertController(title: "Remember Device",
                                                    message: "Do you want to remember this device?.",
                                                    preferredStyle: .actionSheet)
            
            let yesAction = UIAlertAction(title: "Yes", style: .default, handler: { (action) in
                self.rememberDeviceCompletionSource?.set(result: true)
            })
            let noAction = UIAlertAction(title: "No", style: .default, handler: { (action) in
                self.rememberDeviceCompletionSource?.set(result: false)
            })
            alertController.addAction(yesAction)
            alertController.addAction(noAction)
            
            self.window?.rootViewController?.present(alertController, animated: true, completion: nil)
        }
    }
    
    func didCompleteStepWithError(_ error: Error?) {
        DispatchQueue.main.async {
            if let error = error as NSError? {
                let alertController = UIAlertController(title: error.userInfo["__type"] as? String,
                                                        message: error.userInfo["message"] as? String,
                                                        preferredStyle: .alert)
                let okAction = UIAlertAction(title: "ok", style: .default, handler: nil)
                alertController.addAction(okAction)
                DispatchQueue.main.async {
                    self.window?.rootViewController?.present(alertController, animated: true, completion: nil)
                }
            }
        }
    }
}
