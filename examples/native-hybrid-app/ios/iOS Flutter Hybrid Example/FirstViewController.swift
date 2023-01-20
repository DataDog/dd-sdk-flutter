// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import UIKit
import Flutter
import FlutterPluginRegistrant
import Datadog

class FirstViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    @IBAction func openFlutterView(_ sender: Any) {
        let flutterEngine = (UIApplication.shared.delegate as! AppDelegate).flutterEngine
        let flutterViewController = FlutterViewController(engine: flutterEngine, nibName: nil, bundle: nil)
        flutterViewController.modalPresentationStyle = .overFullScreen
        flutterViewController.pushRoute("/")
        
        DismissMethodCallHandler.shared.setDismissListener {
            self.dismiss(animated: true) { [weak self] in
                if let self = self {
                    Global.rum.startView(viewController: self)
                }
            }
        }
        present(flutterViewController, animated: true, completion: nil)
    }
    
    @IBAction func openSecondFlutterView(_ sender: Any) {
        let flutterEngine = (UIApplication.shared.delegate as! AppDelegate).flutterEngine
        let flutterViewController = FlutterViewController(engine: flutterEngine, nibName: nil, bundle: nil)
        flutterViewController.modalPresentationStyle = .overFullScreen
        flutterViewController.pushRoute("/page2")
        DismissMethodCallHandler.shared.setDismissListener {
            self.dismiss(animated: true) { [weak self] in
                if let self = self {
                    Global.rum.startView(viewController: self)
                }
            }
        }
        present(flutterViewController, animated: true, completion: nil)
    }
}

