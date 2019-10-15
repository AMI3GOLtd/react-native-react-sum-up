//
//  sumupBridge.swift
//  SumUpBridge
//
//  Created by Romano Schneider on 02.10.19.
//  Copyright © 2019 Facebook. All rights reserved.
//

import Foundation
import SumUpSDK


@objc(SumUpBridge)
class SumUpBridge: NSObject {
  
  
  func generateJSONResponse(parms:[String:Any]) -> String {
    if let jsonData = try? JSONSerialization.data(withJSONObject: parms, options: []) {
      if let jsonString = String(data: jsonData, encoding: .utf8) {
        print(jsonString)
        return jsonString
      }else{
        return "error"
      }
    }else{
      return "error"
    }
  }
  
  @objc func setupAPIKey(_ apikey :String,
                         resolve: RCTPromiseResolveBlock,
                         rejecter reject: RCTPromiseRejectBlock
  ) -> Void {
    let setAPIKey = SumUpSDK.setup(withAPIKey: apikey)
    if (setAPIKey) {
      resolve(self.generateJSONResponse(parms: ["status":"success"]) )
    } else {
      let error = NSError(domain: "", code: 200, userInfo: [NSLocalizedDescriptionKey: "Can not setup API KEY"])
      reject("ERROR_API_KEY", "Can not setup this API KEY", error)
    }
  }
  
  @objc func presentLoginFromViewController(_ resolve: @escaping RCTPromiseResolveBlock,
                                            rejecter reject: @escaping RCTPromiseRejectBlock
  )-> Void {
   
    DispatchQueue.main.sync {
      guard let rootView = UIApplication.shared.keyWindow?.rootViewController else {
        let newerror = NSError(domain: "", code: 200, userInfo: [NSLocalizedDescriptionKey: "Don't found RootViewController"])
        return reject("ERROR_LOGIN", "Don't found RootViewController", newerror)
      }
      SumUpSDK.presentLogin(from:rootView, animated:true) {(success:Bool, error:Error?) in
        guard error == nil else {
          let newerror = NSError(domain: "", code: 200, userInfo: [NSLocalizedDescriptionKey:String(describing: error)])
          return  reject("ERROR_LOGIN", String(describing: error), newerror)
        }
        if(success){
          resolve(self.generateJSONResponse(parms: ["status":"success"]))
        }else{
          let error = NSError(domain: "", code: 200, userInfo: [NSLocalizedDescriptionKey:String(describing: error)])
          reject("ERROR_LOGIN", String(describing: error), error)
          
        }
      }
    }
  }
  
  @objc func logout(_ resolve: @escaping RCTPromiseResolveBlock,
                    rejecter reject:@escaping RCTPromiseRejectBlock
  ) -> Void {
    SumUpSDK.logout{(success:Bool, error:Error?) in
      if(success){
        resolve(self.generateJSONResponse(parms: ["status":"success"]))
      }else{
        let newerror = NSError(domain: "", code: 200, userInfo: [NSLocalizedDescriptionKey:String(describing: error)])
        reject("ERROR_LOGOUT", String(describing: error), newerror)
        
      }
    }
  }
  
  @objc func loginToSumUpWithToken(_ token:String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock
  ) -> Void {
    let ckeckIsLoggedIN = SumUpSDK.isLoggedIn
    if (ckeckIsLoggedIN){
      resolve(self.generateJSONResponse(parms: ["status":"success", "token":token]))
    }else{
      SumUpSDK.login(withToken: token) { (success:Bool, error:Error?) in
        if(success) {
          resolve(self.generateJSONResponse(parms: ["status":"success", "token":token]))
        }else {
          let newerror = NSError(domain: "", code: 200, userInfo: [NSLocalizedDescriptionKey:String(describing: error)])
          reject("ERRROR_LOGIN_TOKEN",String(describing: error), newerror)
        }
        
      }
      
    }
  }
  
  @objc func isLoggedIn(_ resolve: @escaping RCTPromiseResolveBlock,reject: @escaping RCTPromiseRejectBlock
  ) ->Void {
    let ckeckIsLoggedIN = SumUpSDK.isLoggedIn
    if (ckeckIsLoggedIN){
      resolve(self.generateJSONResponse(parms: ["status":"success"]));
    }
    else {
      let error = NSError(domain: "", code: 200, userInfo: [NSLocalizedDescriptionKey: "Not Login"])
      reject("ERROR_ISLOGGEDIN","Not Login" , error)
    }
  }
  
  @objc func preparePaymentCheckout(_ resolve: @escaping RCTPromiseResolveBlock,reject: @escaping RCTPromiseRejectBlock
  ) ->Void {
    let ckeckIsLoggedIN = SumUpSDK.isLoggedIn
    if (ckeckIsLoggedIN){
      SumUpSDK.prepareForCheckout()
      resolve(nil);
    }else {
      let error = NSError(domain: "", code: 200, userInfo: [NSLocalizedDescriptionKey:"Error by preparePaymentCheckout"])
      reject("ERROR_PREPARE", "Error by preparePaymentCheckout ", error)
    }
  }
  
  @objc func paymentCheckout(_ request:[String: String], resolve: @escaping RCTPromiseResolveBlock,reject: @escaping RCTPromiseRejectBlock ) -> Void {
    
    let title : String
    let total :NSDecimalNumber
    let foreignTrID : String
    if let titleValue = request["titel"]  {
      title=titleValue
    }else {
      print("Error no Title")
      return
    }
    if let totalAmount = request["totalAmount"] {
      total = NSDecimalNumber(string: totalAmount)
    }else{
      return
    }
    guard let merchantCurrencyCode = SumUpSDK.currentMerchant?.currencyCode else {
      return
    }
    if let foreId = request["foreignID"]{
      foreignTrID=foreId
    } else {
      foreignTrID = ""
    }
    guard let skip = request["skipScreenOptions"] else {
      return
    }
    
    
    let checkOutRequest = CheckoutRequest(total: total, title: title, currencyCode: merchantCurrencyCode, paymentOptions: [.cardReader, .mobilePayment])
    if(skip == "true"){
      checkOutRequest.skipScreenOptions = .success
    }
    if(!foreignTrID.isEmpty){
      checkOutRequest.foreignTransactionID = foreignTrID
    }
    DispatchQueue.main.sync {
      guard let rootView = UIApplication.shared.keyWindow?.rootViewController else {
             let newerror = NSError(domain: "", code: 200, userInfo: [NSLocalizedDescriptionKey: "Don't found RootViewController"])
             return reject("ERROR_CHECKOUT", "Don't found RootViewController", newerror)
           }
      SumUpSDK.checkout(with: checkOutRequest, from: rootView) { (result:CheckoutResult?, error:Error?) in
        if let safeError = error as NSError? {
          let firsterror = NSError(domain: "", code: 200, userInfo: nil)
          reject("E_COUNT", "error during checkout: \(safeError)", firsterror)
          
          if (safeError.domain == SumUpSDKErrorDomain) && (safeError.code == SumUpSDKError.accountNotLoggedIn.rawValue) {
            let secondError = NSError(domain: "", code: 200, userInfo: nil)
            reject("E_COUNT", "not logged in: \(safeError)", secondError)
          } else {
            let thirdError = NSError(domain: "", code: 200, userInfo: nil)
            reject("E_COUNT", "general error: \(safeError)", thirdError)
          }
          return
        }
        
        guard let safeResult = result else {
          let safeError = NSError(domain: "", code: 200, userInfo: nil)
          reject("E_COUNT", "no error and no result should not happen: ", safeError)
          print("no error and no result should not happen")
          return
        }
        
        print("transactionCode==\(String(describing: safeResult.transactionCode))")
        var resultObject = [String:Any]()
        if safeResult.success {
          print("success")
          resultObject["status"] = true
          guard let transCode = safeResult.transactionCode else {
            return
          }
          resultObject["transactionCode"] = transCode
          if let info = safeResult.additionalInfo,
                    let foreignTransId = info["foreign_transaction_id"] as? String,
                    let amount = info["amount"] as? NSDecimalNumber{
                    resultObject["amount"]=foreignTransId
                    resultObject["foreignTransactionID"]=amount
          }
               resolve(self.generateJSONResponse(parms: resultObject))
            } else {
               resolve(self.generateJSONResponse(parms: ["status":"false"]))
        }
      }
    }
  }
}