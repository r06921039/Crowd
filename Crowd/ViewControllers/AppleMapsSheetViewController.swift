//
//  File.swift
//  Crowd
//
//  Created by Jeff on 2021/3/1.
//

import UIKit
import UBottomSheet
import MapKit

class AppleMapsSheetViewController: UIViewController, UISearchBarDelegate, UISearchControllerDelegate{
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var SearchBar: UISearchBar!
    var sheetCoordinator: UBottomSheetCoordinator?
    var datasource = MyDataSource()
    var matchingItems:[MKMapItem] = []
    var mapView: MKMapView? = nil
    var handleMapSearchDelegate:HandleMapSearch? = nil
    let defaults = UserDefaults.standard
    var recentSearch = LRUCache<String, MKMapItem>(capacity: 10)
    
    //ADD
    var haveResults = true
    var showSearchView = false
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 11.0, *) {
            tableView.contentInsetAdjustmentBehavior = .never
        } else {
            automaticallyAdjustsScrollViewInsets = false
        }
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UINib(nibName: "EmbeddedCell", bundle: nil), forCellReuseIdentifier: "EmbeddedCell")
        tableView.register(UINib(nibName: "MapItemCell", bundle: nil), forCellReuseIdentifier: "MapItemCell")
        
        SearchBar.delegate = self
//        let tap = UITapGestureRecognizer(target: self, action: #selector(UIInputViewController.dismissKeyboard))
//        view.addGestureRecognizer(tap)
    }
    
    @objc func dismissKeyboard() {
        //Causes the view (or one of its embedded text fields) to resign the first responder status.
        view.endEditing(true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sheetCoordinator?.startTracking(item: self)
        let keys = getUserDefaultsKeys()
        let values = getUsetDefaultsValues()
        if keys.count > 0{
            for i in stride(from: keys.count-1,  through:0, by:-1){
                recentSearch.setObject(for: keys[i], value: values[i])
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        var keys:[String] = []
        var values:[MKMapItem] = []
        if recentSearch.count() > 0{
            for i in 0...recentSearch.count()-1{
                keys.append(recentSearch.renderObject(at: i)!.payload.key)
                values.append(recentSearch.renderObject(at: i)!.payload.value)
            }
        }
        setToUserDefaults(keys)
        setToUserDefaults(values)
    }
    
    func getUserDefaultsKeys() -> [String]{
        if let data = UserDefaults.standard.data(forKey: "recentSearchKey") {
            do{
                let keys = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as! [String]
                return keys
            }
            catch{
                print("Error get Map")
            }
        }
        return []
    }
    
    func getUsetDefaultsValues() -> [MKMapItem]{
        if let data = UserDefaults.standard.data(forKey: "recentSearchValue") {
            do{
                let values = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as! [MKMapItem]
                return values
            }
            catch{
                print("Error get Map")
            }
        }
        return []
    }
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar){
        let availableHeight = sheetCoordinator?.availableHeight
        sheetCoordinator?.setPosition(datasource.initialPosition(availableHeight!), animated:true)
        SearchBar.setShowsCancelButton(true, animated: true)
    }
    
    func searchBarShouldEndEditing(_ searchBar: UISearchBar) -> Bool {
        SearchBar.setShowsCancelButton(false, animated: true)
        return true
    }
    
    @objc func reload(_ searchBar: UISearchBar) {
        
        if searchBar.text == "" || searchBar.text == nil{
            haveResults = true
            showSearchView = false
            self.tableView.reloadData()
        }
        else{
            showSearchView = true
            guard let mapView = mapView,
                let searchBarText = searchBar.text else { return }
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = searchBarText
            request.region = mapView.region
            let search = MKLocalSearch(request: request)
            search.start { response, _ in
                guard let response = response else {
                    self.haveResults = false
                    self.tableView.reloadData()
                    return
                }
                self.haveResults = true
                self.matchingItems = response.mapItems
                self.tableView.reloadData()
            }
        }
    }

    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.reload(_:)), object: searchBar)
        perform(#selector(self.reload(_:)), with: searchBar, afterDelay: 0.3)
        
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        // Stop doing the search stuff
        // and clear the text in the search bar
        searchBar.text = ""
        // Hide the cancel button
        searchBar.showsCancelButton = false
        // You could also change the position, frame etc of the searchBar
        view.endEditing(true)
        haveResults = true
        showSearchView = false
        self.tableView.reloadData()
        let availableHeight = sheetCoordinator?.availableHeight
        sheetCoordinator?.setPosition(availableHeight! * 0.5, animated:true)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        SearchBar.endEditing(true)
    }
    
    func parseAddress(_ selectedItem:MKPlacemark) -> String {
        // put a space between "4" and "Melrose Place"
        let firstSpace = (selectedItem.subThoroughfare != nil && selectedItem.thoroughfare != nil) ? " " : ""
        // put a comma between street and city/state
        let comma = (selectedItem.subThoroughfare != nil || selectedItem.thoroughfare != nil) && (selectedItem.subAdministrativeArea != nil || selectedItem.administrativeArea != nil) ? ", " : ""
        // put a space between "Washington" and "DC"
        let secondSpace = (selectedItem.subAdministrativeArea != nil && selectedItem.administrativeArea != nil) ? " " : ""
        let addressLine = String(
            format:"%@%@%@%@%@%@%@",
            // street number
            selectedItem.subThoroughfare ?? "",
            firstSpace,
            // street name
            selectedItem.thoroughfare ?? "",
            comma,
            // city
            selectedItem.locality ?? "",
            secondSpace,
            // state
            selectedItem.administrativeArea ?? ""
        )
        return addressLine
    }
    
    func coordinateToString(_ location: CLLocationCoordinate2D) -> String{
        let lat = String(location.latitude)
        let long = String(location.longitude)
        return lat + long
    }
    
    func setToUserDefaults(_ location: [MKMapItem]){
        do{
            let data = try NSKeyedArchiver.archivedData(withRootObject: location, requiringSecureCoding: false)
            UserDefaults.standard.set(data, forKey: "recentSearchValue")
        }
        catch{
            print("Error Set Map")
        }
    }
    func setToUserDefaults(_ location: [String]){
        do{
            let data = try NSKeyedArchiver.archivedData(withRootObject: location, requiringSecureCoding: false)
            UserDefaults.standard.set(data, forKey: "recentSearchKey")
        }
        catch{
            print("Error Set String")
        }
    }
}


extension AppleMapsSheetViewController: Draggable{
    func draggableView() -> UIScrollView? {
        return tableView
    }
}

extension AppleMapsSheetViewController: UITableViewDelegate, UITableViewDataSource{
    func numberOfSections(in tableView: UITableView) -> Int {
        if haveResults{
            tableView.backgroundView = nil
            if showSearchView{
                return 1
            }
            else{
                return 2
            }
        }
        else{
            let noDataLabel: UILabel  = UILabel(frame: CGRect(x: 0, y: 0, width: tableView.bounds.size.width, height: tableView.bounds.size.height))
            noDataLabel.text          = "No data available"
            noDataLabel.textColor     = UIColor.black
            noDataLabel.textAlignment = .center
            tableView.backgroundView  = noDataLabel
            tableView.separatorStyle  = .none
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if !showSearchView{
            switch section {
            case 0:
                return 1
            case 1:
                return recentSearch.count()
            default:
                return 0
            }
        }
        else{
            return matchingItems.count
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if !showSearchView{
            switch section {
            case 0:
                return ""
            case 1:
                if recentSearch.count() >= 1{
                return "Recent Searches"
                }
                else{
                    return nil
                }
            default:
                return nil
            }
        }
        else{
            return nil
        }
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return .leastNormalMagnitude
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return nil
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if !showSearchView{
            switch indexPath.section {
            case 0:
                let cell = tableView.dequeueReusableCell(withIdentifier: "EmbeddedCell", for: indexPath) as! EmbeddedCell
                return cell
            default:
                let cell = tableView.dequeueReusableCell(withIdentifier: "MapItemCell", for: indexPath) as! MapItemCell
    //            let title: String
    //            let subtitle: String
    //            switch indexPath.row {
    //            case 0:
    //                title = "Central Park"
    //                subtitle = "New York, NY"
    //            case 1:
    //                title = "American Museum of Natural History"
    //                subtitle = "200 Central Park West, New York, NY"
    //            default:
    //                title = "Tata Innovation Center"
    //                subtitle = "11 E Loop Rd, New York, NY"
    //            }
    //            let model = MapItemCellViewModel(image: nil, title: title, subtitle: subtitle)
    //            cell.configure(model: model)'
                let selectedItem = recentSearch.renderObject(at: indexPath.row)!.payload.value.placemark
                let model = MapItemCellViewModel(image: nil, title: selectedItem.name!, subtitle: parseAddress(selectedItem))
                    cell.configure(model: model)
                return cell
            }
        }
        else{
            let cell = tableView.dequeueReusableCell(withIdentifier: "MapItemCell", for: indexPath) as! MapItemCell
            let selectedItem = matchingItems[indexPath.row].placemark
            let model = MapItemCellViewModel(image: nil, title: selectedItem.name!, subtitle: parseAddress(selectedItem))
                cell.configure(model: model)
            return cell
        }
        
    }
    
//    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        let vc = LabelViewController()
//
//        switch indexPath.row {
//        case 0:
//            let sc = UBottomSheetCoordinator(parent: sheetCoordinator!.parent)
//            vc.sheetCoordinator = sc
//            sc.addSheet(vc, to: sheetCoordinator!.parent)
//        case 1:
//            vc.sheetCoordinator = sheetCoordinator
//            sheetCoordinator?.addSheetChild(vc)
//        default:
//            title = "No Action"
//        }
//        
//    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if showSearchView{
            let selectedItem = matchingItems[indexPath.row].placemark
            handleMapSearchDelegate?.dropPinZoomIn(selectedItem)
            let key = coordinateToString(selectedItem.coordinate)
            recentSearch.setObject(for: key, value: matchingItems[indexPath.row])
            let availableHeight = sheetCoordinator?.availableHeight
            sheetCoordinator?.setPosition(availableHeight! * 0.82, animated:true)
            tableView.reloadData()
            view.endEditing(true)
        }
        else{
            let key = recentSearch.renderObject(at: indexPath.row)!.payload.key
            let selectedItem = recentSearch.retrieveObject(at: key)!.placemark
            handleMapSearchDelegate?.dropPinZoomIn(selectedItem)
            let availableHeight = sheetCoordinator?.availableHeight
            sheetCoordinator?.setPosition(availableHeight! * 0.82, animated:true)
            tableView.reloadData()
            view.endEditing(true)
        }
    }
}





