//
//  ViewController.swift
//  Crowd
//
//  Created by Jeff on 2021/2/26.
//

import UIKit
import UBottomSheet
import MapKit
import SwiftSpinner
import CoreLocation
import Cluster
import Firebase

protocol HandleMapSearch {
    func dropPinZoomIn(_ placemark:MKPlacemark)
}

class MapsViewController: UIViewController, CLLocationManagerDelegate, ClusterManagerDelegate {
    var sheetCoordinator: UBottomSheetCoordinator!
    var backView: PassThroughView?
    var dataSource = MyDataSource()
    @IBOutlet weak var mapView: MKMapView!
    var locationManager = CLLocationManager()
    var selectedPin:MKPlacemark? = nil
    var didLoadData:Bool = false
    var crowdData:Any?
    
    var ref = Database.database().reference()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        locationManager.delegate = self
        mapView.delegate = self
        checkLocationServices()
        if let userLocation = locationManager.location?.coordinate {
            let viewRegion = MKCoordinateRegion(center: userLocation, latitudinalMeters: 1000, longitudinalMeters: 1000)
            mapView.setRegion(viewRegion, animated: false)
        }
        DispatchQueue.main.async {
            self.locationManager.startUpdatingLocation()
        }
        var refHandle = self.ref.observe(DataEventType.value, with: { (snapshot) in
            let postDict = snapshot.value as? [String : AnyObject] ?? [:]
            self.crowdData = CrowdData(postDict["Locations"] as! Array<NSDictionary>)
            if self.selectedPin != nil{
                self.dropPinZoomIn(self.selectedPin!)
            }
        })
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !didLoadData{
            self.demoSpinner()
            didLoadData = true
        }
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        guard sheetCoordinator == nil else {return}
        sheetCoordinator = UBottomSheetCoordinator(parent: self,
                                                   delegate: self)
        sheetCoordinator.dataSource = dataSource
        let vc = AppleMapsSheetViewController()
        vc.sheetCoordinator = sheetCoordinator
        vc.mapView = mapView
        vc.handleMapSearchDelegate = self
        
        sheetCoordinator.addSheet(vc, to: self, didContainerCreate: { container in
            let f = self.view.frame
            let rect = CGRect(x: f.minX, y: f.minY, width: f.width, height: f.height)
            container.roundCorners(corners: [.topLeft, .topRight], radius: 10, rect: rect)
        })
        sheetCoordinator.setCornerRadius(10)
        
    }
    
    
    private func addBackDimmingBackView(below container: UIView){
        backView = PassThroughView()
        self.view.insertSubview(backView!, belowSubview: container)
        backView!.translatesAutoresizingMaskIntoConstraints = false
        backView!.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        backView!.bottomAnchor.constraint(equalTo: container.topAnchor, constant: 10).isActive = true
        backView!.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
        backView!.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true
    }
    
    func delay(seconds: Double, completion: @escaping () -> ()) {
        let popTime = DispatchTime.now() + Double(Int64( Double(NSEC_PER_SEC) * seconds )) / Double(NSEC_PER_SEC)
            
        DispatchQueue.main.asyncAfter(deadline: popTime) {
            completion()
        }
    }

    func demoSpinner() {
        SwiftSpinner.show(delay: 0.0, title: "Connecting \nto Crowd...", animated: true)
                
        
        ref.child("Locations").getData { (error, snapshot) in
            if let error = error {
                print("Error getting data \(error)")
            }
            else if snapshot.exists() {
                self.crowdData = CrowdData(snapshot.value! as! Array<NSDictionary>)
            }
            else {
                print("No data available")
            }
            SwiftSpinner.hide()
        }
    }
    
    func checkLocationServices() {
      if CLLocationManager.locationServicesEnabled() {
        checkLocationAuthorization()
      } else {
        // Show alert letting the user know they have to turn this on.
      }
    }
    
    func locationAuthorizationStatus() -> CLAuthorizationStatus {
        var locationAuthorizationStatus : CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            locationAuthorizationStatus =  locationManager.authorizationStatus
        } else {
            // Fallback on earlier versions
            locationAuthorizationStatus = CLLocationManager.authorizationStatus()
        }
        return locationAuthorizationStatus
    }
    
    func checkLocationAuthorization() {
        switch locationAuthorizationStatus() {
        case .authorizedWhenInUse:
            mapView.showsUserLocation = true
        case .denied: // Show alert telling users how to turn on permissions
            break
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            mapView.showsUserLocation = true
        case .restricted: // Show an alert letting them know what’s up
            break
        case .authorizedAlways:
            break
        default:
            break
      }
    }
    
}

extension MapsViewController: UBottomSheetCoordinatorDelegate{
    
    func bottomSheet(_ container: UIView?, didPresent state: SheetTranslationState) {
//        self.addBackDimmingBackView(below: container!)
        self.sheetCoordinator.addDropShadowIfNotExist()
        self.handleState(state)
    }

    func bottomSheet(_ container: UIView?, didChange state: SheetTranslationState) {
        handleState(state)
    }

    func bottomSheet(_ container: UIView?, finishTranslateWith extraAnimation: @escaping ((CGFloat) -> Void) -> Void) {
        extraAnimation({ percent in
            self.backView?.backgroundColor = UIColor.black.withAlphaComponent(percent/100 * 0.8)
        })
    }
    
    func handleState(_ state: SheetTranslationState){
        switch state {
        case .progressing(_, let percent):
            self.backView?.backgroundColor = UIColor.black.withAlphaComponent(percent/100 * 0.8)
        case .finished(_, let percent):
            self.backView?.backgroundColor = UIColor.black.withAlphaComponent(percent/100 * 0.8)
        default:
            break
        }
    }
}

extension MapsViewController: HandleMapSearch {
    func dropPinZoomIn(_ placemark:MKPlacemark){
        // cache the pin
        selectedPin = placemark
        // clear existing pins
        mapView.removeAnnotations(mapView.annotations)
        let annotation = MKPointAnnotation()
        annotation.coordinate = placemark.coordinate
        annotation.title = placemark.name
        if let city = placemark.locality,
        let state = placemark.administrativeArea {
            annotation.subtitle = "\(city) \(state)"
        }
        DispatchQueue.main.async {
            self.mapView.addAnnotation(annotation) //Yes!! This method adds the annotations
        }
        //mapView.addAnnotation(annotation)
        let viewRegion = MKCoordinateRegion(center: annotation.coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000)
        mapView.setRegion(viewRegion, animated: false)
    }
}

extension MapsViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        // Don't want to show a custom image if the annotation is the user's location.
        guard !(annotation is MKUserLocation) else {
            return nil
        }
        // Better to make this class property
        let annotationIdentifier = "AnnotationIdentifier"

        var annotationView: MKAnnotationView?
        if let dequeuedAnnotationView = mapView.dequeueReusableAnnotationView(withIdentifier: annotationIdentifier) {
            annotationView = dequeuedAnnotationView
            annotationView?.annotation = annotation
        }
        else {
            let av = MKAnnotationView(annotation: annotation, reuseIdentifier: annotationIdentifier)
            av.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
            annotationView = av
        }

        if let annotationView = annotationView {
            // Configure your annotation view here
            let view = ImageCountClusterAnnotationView(annotation: annotation, reuseIdentifier: annotationIdentifier)
            let lat = String(annotation.coordinate.latitude)
            let long = String(annotation.coordinate.longitude)
            let key = lat + long
            let data = crowdData as! CrowdData
            let table = data.getTable()
            let percent = table[key]
            //let imageName = "crowded_" + "\(percent!)"
            //print(imageName)
            //view.image = UIImage(named: imageName)
            //view.image = .pin2
            //let percent_s = percent != nil ? "\(percent!)" : ""
            if percent != nil{
                view.countLabel.text = "\(percent!)"
            }
            else{
                view.countLabel.text = "NaN"
            }
            view.layoutSubviews()
            return view
        }

        return annotationView
    }
}



