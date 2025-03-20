//
//  HFM3U8FileDownloadOperation.swift
//  BNM3u8Cache
//
//  Created by HF on 2025/3/18.
//  Copyright © 2025 Bennie. All rights reserved.
//

import Foundation

class HFM3U8FileDownloadOperation {
    var fileInfo: BNM3U8FileDownloadProtocol?
    var speedBlock: ((_ count: Int)->Void)?
    var resultBlock: ((_ info: Any, _ error: Error)->Void)?
    var executing: Bool = false
    var finished: Bool = false
    var dataTask: URLSessionDownloadTask?

    func start() {
        let config = URLSessionConfiguration.default
        let currentSession = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
        self.dataTask = currentSession.downloadTask(with: URLRequest(), completionHandler: { URL, response, error in
            
        })
    }
}
