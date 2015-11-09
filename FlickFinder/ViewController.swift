//
//  ViewController.swift
//  Flick Finder
//
//  Created by Ada Ji on 11/6/15.
//  Copyright © 2015 Ada Ji. All rights reserved.
//

import UIKit

// MARK: - Globals

let BASE_URL = "https://api.flickr.com/services/rest/"
let METHOD_NAME = "flickr.photos.search"
let API_KEY = "524445849254a06e0f74562c717c6f95"
let SAFE_SEARCH = "1"
let EXTRAS = "url_m"
let DATA_FORMAT = "json"
let NO_JSON_CALLBACK = "1"
let BOUNDING_BOX_HALF_WIDTH = 1.0
let BOUNDING_BOX_HALF_HEIGHT = 1.0
let LAT_MIN = -90.0
let LAT_MAX = 90.0
let LON_MIN = -180.0
let LON_MAX = 180.0

// MARK: - String Extension

extension String {
    func toDouble() -> Double? {
        return NSNumberFormatter().numberFromString(self)?.doubleValue
    }
}

// MARK: - View Controller: UIViewController

class ViewController: UIViewController, UITextFieldDelegate {
    
    // MARK: Properties

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var phraseTextField: UITextField!
    @IBOutlet weak var latitudeTextField: UITextField!
    @IBOutlet weak var longitudeTextField: UITextField!
    @IBOutlet weak var imageTitleLabel: UILabel!
    
    var tapRecognizer: UITapGestureRecognizer? = nil
    
    var currentKeyboardHeight: CGFloat? = 0
    
    // MARK: Actions
    
    @IBAction func searchByPhrase(sender: UIButton) {
        searchImageByPhrase()
    }
    
    @IBAction func searchByLatLon(sender: UIButton) {
        searchImageByLatLon()
    }
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tapRecognizer = UITapGestureRecognizer(target: self, action: "handleSingleTap:")
        tapRecognizer?.numberOfTapsRequired = 1
        
        phraseTextField.delegate = self
        latitudeTextField.delegate = self
        longitudeTextField.delegate = self
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        addKeyboardDismissRecognizer()
        
        subscribeToKeyboardNotifications()
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        removeKeyboardDismissRecognizer()
        
        unsubscribeToKeyboardNotifications()
    }
    
    // MARK: Text Field Delegate
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        if textField == phraseTextField {
            textField.resignFirstResponder()
            
            searchImageByPhrase()
        }
        else if textField == latitudeTextField {
            longitudeTextField.becomeFirstResponder()
        }
        else if textField == longitudeTextField {
            textField.resignFirstResponder()
            
            searchImageByLatLon()
        }
        
        return true
    }
    
    // MARK: Search
    
    func searchImageByPhrase() {
        dismissKeyboard()
        
        resetView()
        latitudeTextField.text = ""
        longitudeTextField.text = ""

        let phrase = phraseTextField.text!
        if !phrase.isEmpty {
            messageLabel.text = "Searching for \(phrase) image..."
            imageTitleLabel.text = "(\(phrase)) "
            
            let methodArguments = [
                "method": METHOD_NAME,
                "api_key": API_KEY,
                "text": phrase,
                "safe_search": SAFE_SEARCH,
                "extras": EXTRAS,
                "format": DATA_FORMAT,
                "nojsoncallback": NO_JSON_CALLBACK
            ]
            //            getImageFromFlickr(methodArguments)
            getImageFromFlickrWithPage(methodArguments, pageNumber: 1)
        } else {
            displayErrorMessage("Phrase Empty.")
        }
    }
    
    func searchImageByLatLon() {
        dismissKeyboard()
        
        resetView()
        phraseTextField.text = ""
        
        if !latitudeTextField.text!.isEmpty && !longitudeTextField.text!.isEmpty {
            if validLatitude() && validLongitude() {
                let loc = getLatLonString()
                messageLabel.text = "Searching for image at \(loc)..."
                imageTitleLabel.text = "\(loc) "
                
                let methodArguments = [
                    "method": METHOD_NAME,
                    "api_key": API_KEY,
                    "bbox": createBoundingBoxString(latitudeTextField.text!, longitude: longitudeTextField.text!),
                    "safe_search": SAFE_SEARCH,
                    "extras": EXTRAS,
                    "format": DATA_FORMAT,
                    "nojsoncallback": NO_JSON_CALLBACK
                ]
                //            getImageFromFlickr(methodArguments)
                getImageFromFlickrWithPage(methodArguments, pageNumber: 1)
            } else {
                if !validLatitude() && !validLongitude() {
                    displayErrorMessage("Lat/Lon Invalid.\nLat should be [-90, 90].\nLon should be [-180, 180].")
                } else if !validLatitude() {
                    displayErrorMessage("Lat Invalid.\nLat should be [-90, 90].")
                } else {
                    displayErrorMessage("Lon Invalid.\nLon should be [-180, 180].")
                }
            }
        } else {
            if latitudeTextField.text!.isEmpty && longitudeTextField.text!.isEmpty {
                displayErrorMessage("Lat/Lon Empty.")
            } else if latitudeTextField.text!.isEmpty {
                displayErrorMessage("Lat Empty.")
            } else {
                displayErrorMessage("Lon Empty.")
            }
        }
    }
    
    // MARK: Lat/Lon Manipulation
    
    // Check to make sure the latitude falls within [-90, 90]
    func validLatitude() -> Bool {
        if let latitude: Double? = latitudeTextField.text!.toDouble() {
            if latitude < LAT_MIN || latitude > LAT_MAX {
                return false
            }
        } else {
            return false
        }
        return true
    }
    
    // Check to make sure the longitude falls within [-180, 180]
    func validLongitude() -> Bool {
        if let longitude: Double? = longitudeTextField.text!.toDouble() {
            if longitude < LON_MIN || longitude > LON_MAX {
                return false
            }
        } else {
            return false
        }
        return true
    }
    
    func getLatLonString() -> String {
        let latitude = (latitudeTextField.text! as NSString).doubleValue
        let longitude = (longitudeTextField.text! as NSString).doubleValue
        return "(\(latitude), \(longitude))"
    }
    
    func createBoundingBoxString(latitude: String, longitude: String) -> String {
        let lat = (latitude as NSString).doubleValue
        let lon = (longitude as NSString).doubleValue
        let lon_min = max(lon - BOUNDING_BOX_HALF_WIDTH, LON_MIN)
        let lat_min = max(lat - BOUNDING_BOX_HALF_HEIGHT, LAT_MIN)
        let lon_max = min(lon + BOUNDING_BOX_HALF_WIDTH, LON_MAX)
        let lat_max = min(lat + BOUNDING_BOX_HALF_HEIGHT, LAT_MAX)
        return "\(lon_min), \(lat_min), \(lon_max), \(lat_max)"
    }
    
    // MARK: Flickr API
    
    // This function makes the first request to get a random page number, then it makes a request to get an image with the random page
    func getImageFromFlickr(methodArguments: [String: AnyObject]) {
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

                    if let totalPages = parsedResult["pages"] as? Int {
                        let pageLimit = min(totalPages, 40)
                        let randomPage = Int(arc4random_uniform(UInt32(pageLimit))) + 1
                        self.getImageFromFlickrWithPage(methodArguments, pageNumber: randomPage)
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
    
    func getImageFromFlickrWithPage(methodArguments: [String: AnyObject], pageNumber: Int) {
        var withPageDictionary = methodArguments
        withPageDictionary["page"] = pageNumber
        
        let session = NSURLSession.sharedSession()
        let urlString = BASE_URL + escapedParameters(withPageDictionary)
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
                                            self.messageLabel.alpha = 0.0 // * Is this more efficient than ".hidden = true" ?
                                            self.imageView.image = UIImage(data: imageData)
                                            self.imageTitleLabel.text = self.imageTitleLabel.text! + (imageTitle ?? "(Untitled)")
                                        })
                                    }
                                }
                            }
                        } else {
                            dispatch_async(dispatch_get_main_queue(), {
                                self.resetView()
                                self.messageLabel.text = "No photos found. Search again."
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
    
    // MARK: Show/Hide Keyboard
    
    func addKeyboardDismissRecognizer() {
        view.addGestureRecognizer(tapRecognizer!)
    }
    
    func removeKeyboardDismissRecognizer() {
        view.removeGestureRecognizer(tapRecognizer!)
    }
    
    func handleSingleTap(recognizer: UITapGestureRecognizer) {
        view.endEditing(true)
    }
    
    func subscribeToKeyboardNotifications() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillShow:", name: UIKeyboardWillShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillHide:", name: UIKeyboardWillHideNotification, object: nil)
    }
    
    func unsubscribeToKeyboardNotifications() {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    func keyboardWillShow(notification: NSNotification) {
        if view.frame.origin.y == 0.0 {
            if currentKeyboardHeight == 0.0 {
                currentKeyboardHeight = getKeyboardHeight(notification)
                view.frame.origin.y -= currentKeyboardHeight! / 2 + 30.0
            }
        }
    }
    
    func keyboardWillHide(notification: NSNotification) {
        if view.frame.origin.y != 0.0 {
            if currentKeyboardHeight != 0.0 {
                view.frame.origin.y += currentKeyboardHeight! / 2 + 30.0
                currentKeyboardHeight = 0.0
            }
        }
    }
    
    func getKeyboardHeight(notification: NSNotification) -> CGFloat {
        let userInfo = notification.userInfo
        let keyboardSize = userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue // of CGRect
        return keyboardSize.CGRectValue().height
    }
    
    // MARK: Escape HTML Parameters
    
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

// MARK: - ViewController Extension

extension ViewController {
    func resetView() {
        imageView.image = nil
        messageLabel.textColor = UIColor.whiteColor()
        messageLabel.alpha = 1.0
        imageTitleLabel.text = ""
    }
    
    func displayErrorMessage(message: String) {
        messageLabel.textColor = UIColor.redColor()
        messageLabel.text = message
    }
    
    func dismissKeyboard() {
        if phraseTextField.isFirstResponder() || latitudeTextField.isFirstResponder() || longitudeTextField.isFirstResponder() {
            view.endEditing(true)
        }
    }
}












