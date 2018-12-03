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

import Foundation
import AWSCognitoIdentityProvider
import UIKit

class SignInViewController: UIViewController {
    // 認証周り
    @IBOutlet weak var username: UITextField!
    @IBOutlet weak var password: UITextField!
    var passwordAuthenticationCompletion: AWSTaskCompletionSource<AWSCognitoIdentityPasswordAuthenticationDetails>?
    var usernameText: String?
    var pool: AWSCognitoIdentityUserPool?
    var user: AWSCognitoIdentityUser?
    // 処理中のクルクル
    var ActivityIndicator: UIActivityIndicatorView!
    
    // 画面表示初期に一度だけ実行する処理
    override func viewDidLoad() {
        super.viewDidLoad()
        // ActivityIndicatorを作成&中央に配置
        ActivityIndicator = UIActivityIndicatorView()
        ActivityIndicator.backgroundColor = .lightGray
        ActivityIndicator.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
        ActivityIndicator.center = self.view.center
        // クルクルをStopした時に非表示にする
        ActivityIndicator.hidesWhenStopped = true
        // 色を設定
        ActivityIndicator.style = UIActivityIndicatorView.Style.gray
        // Viewに追加
        self.view.addSubview(ActivityIndicator)
    }
    // 認証用処理
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.password.text = nil
        self.username.text = usernameText
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        self.pool = AWSCognitoIdentityUserPool(forKey: AWSCognitoUserPoolsSignInProviderKey)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
    
    // 画面遷移用
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        DispatchQueue.main.async {
        if (segue.identifier == "toMotionCaptureViewController") {
            let mcvc: MotionCaptureViewController = (segue.destination as? MotionCaptureViewController)!
            mcvc.textMCVC = self.username.text!
        }
        }
    }
    
    @IBAction func signInPressed(_ sender: AnyObject) {
        if (self.username.text != "" && self.password.text != "") {
            let authDetails = AWSCognitoIdentityPasswordAuthenticationDetails(username: self.username.text!, password: self.password.text! )
            self.passwordAuthenticationCompletion?.set(result: authDetails)
            print("入力あり")
            print(self.username.text!)
            print(self.password.text!)
            // クルクルスタート
            self.ActivityIndicator.startAnimating()
            user = self.pool!.getUser(self.username.text!)
            user?.getSession(self.username.text!, password:self.password.text!, validationData: nil).continueWith(block: {task in
                // 認証結果処理
                if task.error != nil {
                    // クルクルストップ
                    self.ActivityIndicator.stopAnimating()
                    print("ログイン失敗")
                    let alertController = UIAlertController(title: "Missing information",
                                                            message: "Please enter a valid user name and password",
                                                            preferredStyle: .alert)
                    let retryAction = UIAlertAction(title: "Retry", style: .default, handler: nil)
                    alertController.addAction(retryAction)
                    self.present(alertController, animated: true, completion:  nil)
                } else {
                    print("ログイン成功")
                    DispatchQueue.main.async {
                        self.performSegue(withIdentifier: "toMotionCaptureViewController",sender: nil)
                        self.ActivityIndicator.stopAnimating()
                    }
                }
                return task
            })
        } else {
            let alertController = UIAlertController(title: "No input",
                                                    message: "Please enter user name and password",
                                                    preferredStyle: .alert)
            let retryAction = UIAlertAction(title: "Retry", style: .default, handler: nil)
            alertController.addAction(retryAction)
            self.present(alertController, animated: true, completion:  nil)
        }
    }
}

extension SignInViewController: AWSCognitoIdentityPasswordAuthentication {
    
    public func getDetails(_ authenticationInput: AWSCognitoIdentityPasswordAuthenticationInput, passwordAuthenticationCompletionSource: AWSTaskCompletionSource<AWSCognitoIdentityPasswordAuthenticationDetails>) {
        self.passwordAuthenticationCompletion = passwordAuthenticationCompletionSource
        DispatchQueue.main.async {
            if (self.usernameText == nil) {
                self.usernameText = authenticationInput.lastKnownUsername
            }
        }
    }
    
    public func didCompleteStepWithError(_ error: Error?) {
        DispatchQueue.main.async {
            if let error = error as NSError? {
                let alertController = UIAlertController(title: error.userInfo["__type"] as? String,
                                                        message: error.userInfo["message"] as? String,
                                                        preferredStyle: .alert)
                let retryAction = UIAlertAction(title: "Retry", style: .default, handler: nil)
                alertController.addAction(retryAction)
                
                self.present(alertController, animated: true, completion:  nil)
            } else {
                self.username.text = nil
                self.dismiss(animated: true, completion: nil)
            }
        }
    }
}
