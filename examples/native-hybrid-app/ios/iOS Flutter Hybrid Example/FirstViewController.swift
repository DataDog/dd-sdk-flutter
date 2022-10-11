// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import UIKit
import Flutter
import FlutterPluginRegistrant

class FirstViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    @IBAction func openFlutterView(_ sender: Any) {
        let flutterViewController =
            FlutterViewController(project: nil, nibName: nil, bundle: nil)
        GeneratedPluginRegistrant.register(with: flutterViewController.engine!);
        present(flutterViewController, animated: true, completion: nil)
    }
}

