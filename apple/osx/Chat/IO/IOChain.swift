//
//  IOManager.swift
//  Chat
//
//  Created by Ivan Khvorostinin on 16/05/2017.
//  Copyright © 2017 ys1382. All rights reserved.
//

import Foundation

class IOChain : IOProtocol
{
    
    static let shared = IOChain()
    
    private var ios = [IOProtocol]()
    
    private init()
    {
        
    }
    
    func register(_ io: IOProtocol)
    {
        ios.append(io);
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // IOProtocol
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    func start()
    {
        for i in ios
        {
            i.start()
        }
    }
    
    func stop()
    {
        for i in ios
        {
            i.stop()
        }
    }
}
