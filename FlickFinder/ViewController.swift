//
//  ViewController.swift
//  Flick Finder
//
//  Created by Ada Ji on 11/6/15.
//  Copyright © 2015 Ada Ji. All rights reserved.
//

import UIKit

// MARK: Globals

let BASE_URL = "https://api.flickr.com/services/rest/"
let METHOD_NAME = "flickr.photos.search"
let API_KEY = "524445849254a06e0f74562c717c6f95"
let SAFE_SEARCH = "1"
let EXTRAS = "url_m"
let DATA_FORMAT = "json"
let NO_JSON_CALLBACK = "1"

class ViewController: UIViewController, UITextFieldDelegate {
    
    // MARK: Properties

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var imageLabel: UILabel!
    @IBOutlet weak var phraseField: UITextField!
    @IBOutlet weak var latitudeField: UITextField!
    @IBOutlet weak var longitudeField: UITextField!
    @IBOutlet weak var titleLabel: UILabel!
    
    var keyboardIsShowing: Bool!
    
    // MARK: Actions
    
    @IBAction func searchByPhrase(sender: UIButton) {
        searchImageByPhrase()
    }
    
    func searchImageByPhrase() {
        resetView()
        imageLabel.text = "Searching..."
        getImageFromFlickr()
    }
    
    // MARK: Flickr API
    
    func getImageFromFlickr() {
        let methodArguments = [
            "method": METHOD_NAME,
            "api_key": API_KEY,
            "text": phraseField.text!,
            "safe_search": SAFE_SEARCH,
            "extras": EXTRAS,
            "format": DATA_FORMAT,
            "nojsoncallback": NO_JSON_CALLBACK
        ]
        
        let session = NSURLSession.sharedSession()
        let urlString = BASE_URL + escapedParameters(methodArguments)
        let request = NSURLRequest(URL: NSURL(string: urlString)!)
        
        let task = session.dataTaskWithRequest(request) { (data, response, downloadError) in
            
            if let error = downloadError {
                print("Could not complete the request \(error)")
            } else {
                let parsedResult: AnyObject!
                do {
                    parsedResult = try NSJSONSerialization.JSONObjectWithData(data!, options: .AllowFragments) as! NSDictionary

                    if let photosDictionary = parsedResult["photos"] as? [String: AnyObject] {
                        var totalVar = 0
                        if let total = photosDictionary["total"] as? String {
                            totalVar = (total as NSString).integerValue
                        }
                        
                        if totalVar > 0 {
                            if let photosArray = photosDictionary["photo"] as? [[String: AnyObject]] {
                                let index = Int(arc4random_uniform(UInt32(photosArray.count)))
                                let photoDictionary = photosArray[index]
                                let imageTitle = photoDictionary["title"] as? String // non-fatal
                                if let imageUrlString = photoDictionary["url_m"] as? String {
                                    let imageUrl = NSURL(string: imageUrlString)
                                    if let imageData = NSData(contentsOfURL: imageUrl!) {
                                        dispatch_async(dispatch_get_main_queue(), {
                                            self.imageLabel.alpha = 0.0 // * Is this more efficient than ".hidden = true" ?
                                            self.imageView.image = UIImage(data: imageData)
                                            self.titleLabel.text = imageTitle ?? "(Untitled)"
                                        })
                                    }
                                }
                            }
                        } else {
                            dispatch_async(dispatch_get_main_queue(), {
                                self.resetView()
                                self.imageLabel.text = "No photos found. Search again."
                            })
                        }
                    }
                    
                } catch {
                    parsedResult = nil
                    print("Could not parse the data as JSON: '\(data)'")
                    return
                }
            }
        }
        
        task.resume()
    }
    
    @IBAction func searchByLatLon(sender: UIButton) {
        
    }
    
    // MARK: Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        keyboardIsShowing = false

        phraseField.delegate = self
        latitudeField.delegate = self
        longitudeField.delegate = self
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        subscribeToKeyboardNotifications()
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        unsubscribeToKeyboardNotifications()
    }

    // MARK: Text Field Delegate
    
    func textFieldShouldBeginEditing(textField: UITextField) -> Bool {
        addKeyboardDismissRecognizer()
        
        return true
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        if textField == phraseField {
            textField.resignFirstResponder()
            
            searchImageByPhrase()
        }
        
        return true
    }
    
    func textFieldShouldEndEditing(textField: UITextField) -> Bool {
        removeKeyboardDismissRecognizer()
        
        return true
    }
    
    // MARK: Show/Hide Keyboard
    
    // Adjust view frame when keyboard shows/hides
    
    func addKeyboardDismissRecognizer() {
        let recognizer = UITapGestureRecognizer(target: self, action: "handleSingleTap:")
        view.addGestureRecognizer(recognizer)
    }
    
    func removeKeyboardDismissRecognizer() {
        //        view.removeGestureRecognizer(recognizer)
    }
    
    func handleSingleTap(recognizer: UITapGestureRecognizer) {
        if phraseField.isFirstResponder() {
            phraseField.resignFirstResponder()
        }
        else if latitudeField.isFirstResponder() {
            latitudeField.resignFirstResponder()
        }
        else if longitudeField.isFirstResponder() {
            longitudeField.resignFirstResponder()
        }
    }
    
    func subscribeToKeyboardNotifications() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillShow:", name: UIKeyboardWillShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillHide:", name: UIKeyboardWillHideNotification, object: nil)
    }
    
    func unsubscribeToKeyboardNotifications() {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    func keyboardWillShow(notification: NSNotification) {
        if !keyboardIsShowing! {
            moveViewVertically(getKeyboardHeight(notification), up: true)
            keyboardIsShowing = true
        }
    }
    
    func keyboardWillHide(notification: NSNotification) {
        if keyboardIsShowing! {
            moveViewVertically(getKeyboardHeight(notification), up: false)
            keyboardIsShowing = false
        }
    }
    
    func moveViewVertically(distance: CGFloat, up: Bool) {
        let dist = distance * (up ? -1 : 1)
        view.frame.origin.y += dist
    }
    
    func getKeyboardHeight(notification: NSNotification) -> CGFloat {
        let userInfo = notification.userInfo
        let keyboardSize = userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue // of CGRect
        return keyboardSize.CGRectValue().height
    }
    
    // MARK: Helper Functions
    
    func resetView() {
        imageView.image = nil
        imageLabel.alpha = 1.0
        titleLabel.text = ""
    }
    
    /* Helper function: Given a dictionary of parameters, convert to a string for a url */
    func escapedParameters(parameters: [String : AnyObject]) -> String {
        
        var urlVars = [String]()
        
        for (key, value) in parameters {
            
            /* Make sure that it is a string value */
            let stringValue = "\(value)"
            
            /* Escape it */
            let escapedValue = stringValue.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
            
            /* Append it */
            urlVars += [key + "=" + "\(escapedValue!)"]
            
        }
        
        return (!urlVars.isEmpty ? "?" : "") + urlVars.joinWithSeparator("&")
    }
    
}

