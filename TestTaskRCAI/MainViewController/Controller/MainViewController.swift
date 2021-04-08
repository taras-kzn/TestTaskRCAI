//
//  MainViewController.swift
//  TestTaskRCAI
//
//  Created by admin on 05.04.2021.
//

import UIKit
import MapKit
import CoreLocation

final class MainViewController: UIViewController {
    
// MARK: - IBOutlet
    @IBOutlet var mapView: MKMapView!
    @IBOutlet var addresLabel: UILabel!
    @IBOutlet var startLabel: UIButton!
    @IBOutlet var clearLabel: UIButton!
    @IBOutlet var pinLabel: UIButton!
    
    // MARK: - Private Propertues
    private let locatioManager = CLLocationManager()
    private let regionInMeters: Double = 7000
    private let geocoder = CLGeocoder()
    private var groupedRoutes: [(startItem: MKMapItem , endItem: MKMapItem )] = []
    private var directionsArray : [MKDirections] = []
    private var oneLocation: CLLocation?
    private var onePlacmark: MKPlacemark?
    private var oneMKItem: MKMapItem?
    private var arrayAnnotation: [MKPointAnnotation] = []
    private var titleMarker: String?
    private var cityMarker: String?
    private var arrayMapITem: [MKMapItem] = []
    private var isButton = true
    private var count = 0
    
//MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        config()
    }
// MARK: - Functions config Location
    private func config() {
        mapView.delegate = self
        startLabel.isHidden = true
        clearLabel.isHidden = true
        pinLabel.layer.cornerRadius = pinLabel.frame.width / 2
        pinLabel.layer.masksToBounds = true
        startLabel.layer.cornerRadius = startLabel.frame.width / 2.5
        startLabel.layer.masksToBounds = true
        clearLabel.layer.cornerRadius = clearLabel.frame.width / 2.5
        clearLabel.layer.masksToBounds = true
        checkLocationServices()
    }
    
    private func setupLocationManager() {
        locatioManager.delegate = self
        locatioManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    private func centerViewLocation() {
        guard let location = locatioManager.location?.coordinate else {
            return }
        let region = MKCoordinateRegion(center: location, latitudinalMeters: regionInMeters, longitudinalMeters: regionInMeters)
        mapView.setRegion(region, animated: true)
    }
    
    private func checkLocationServices() {
        guard CLLocationManager.locationServicesEnabled() else {
            return
        }
        setupLocationManager()
        checkLocationAuthoriation()
    }
    
    private func checkLocationAuthoriation() {
        switch CLLocationManager.authorizationStatus() {
        case .authorizedWhenInUse:
            startTrackingLocation()
        case .denied:
            break
        case .notDetermined:
            locatioManager.requestWhenInUseAuthorization()
            break
        case .authorizedAlways:
            break
        case .restricted:
            break
        }
    }
    
    private func startTrackingLocation() {
        mapView.showsUserLocation = true
        centerViewLocation()
        locatioManager.startUpdatingLocation()
        oneLocation = getCentrLocation(mapView: mapView)
    }
    
    private func getCentrLocation(mapView: MKMapView) -> CLLocation {
        let latitude = mapView.centerCoordinate.latitude
        let longitude = mapView.centerCoordinate.longitude
        
        return CLLocation(latitude: latitude, longitude: longitude)
    }
    
// MARK: - Function Action
    private func start() {
        guard let location = locatioManager.location?.coordinate else { return }
        guard let firstStop = self.arrayMapITem.first else { return }
        let startplaceMark = MKPlacemark(coordinate: location)
        let startITem = MKMapItem(placemark: startplaceMark)
        groupedRoutes.append((startITem, firstStop))
        
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            if self.arrayMapITem.count > 0 {
                for i in self.arrayMapITem {
                    let startPoint = i
                    for endPoint in self.arrayMapITem {
                        if endPoint != startPoint {
                            DispatchQueue.main.async {
                                self.groupedRoutes.append((startPoint, endPoint))
                                self.fetchNextRoute()
                            }
                        self.arrayMapITem.removeFirst()
                        break
                        }
                    }
                }
            }
        }
        fetchNextRoute()
    }
    
    func fetchNextRoute() {
        guard !groupedRoutes.isEmpty else { return }
        let nextGroup = groupedRoutes.removeFirst()
        let request = MKDirections.Request()
        request.source = nextGroup.startItem
        request.destination = nextGroup.endItem
        request.transportType = .automobile
        let directions = MKDirections(request: request)
        directionsArray.append(directions)
        
        directions.calculate { [weak self] (response, _) in
            guard let self = self else { return }
            guard let mapRoute = response?.routes.first else { return }
            let padding: CGFloat = 8
            self.mapView.addOverlay(mapRoute.polyline)
            self.mapView.setVisibleMapRect(
                self.mapView.visibleMapRect.union(
                    mapRoute.polyline.boundingMapRect
                ),
                edgePadding: UIEdgeInsets(
                    top: 0,
                    left: padding,
                    bottom: padding,
                    right: padding
                ),
                animated: true
            )
            self.fetchNextRoute()
        }
    }
    
    private func addMarkerPin() {
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            guard let newLocation = self.oneLocation else { return }
            self.onePlacmark = MKPlacemark(coordinate: newLocation.coordinate, addressDictionary: nil)
            guard let newPlacmark = self.onePlacmark else { return }
            self.oneMKItem = MKMapItem(placemark: newPlacmark)
            if let testITem = self.oneMKItem {
                self.arrayMapITem.append(testITem)
            }
            let sourceAnnotation = MKPointAnnotation()
            let title = self.titleMarker ?? ""
            let city = self.cityMarker ?? ""
            sourceAnnotation.title = "\(city) \(title)"
            guard let location = newPlacmark.location else { return }
            sourceAnnotation.coordinate = location.coordinate
            self.arrayAnnotation.append(sourceAnnotation)
            let annotation = self.arrayAnnotation
            self.count += 1
            DispatchQueue.main.async {
                self.mapView.showAnnotations(annotation, animated: true )
                if self.count == 3 {
                    self.startLabel.isHidden = false
                    self.clearLabel.isHidden = false
                }
            }
        }
    }
    
    private func removeDirectionsAndMarker() {
        mapView.removeOverlays(mapView.overlays)
        let _ = directionsArray.map { $0.cancel() }
        groupedRoutes.removeAll()
        directionsArray.removeAll()
        arrayMapITem.removeAll()
        mapView.removeAnnotations(arrayAnnotation)
        arrayAnnotation.removeAll()
        count = 0
        startLabel.isHidden = true
        clearLabel.isHidden = true
    }
// MARK: - IBAction Action
    @IBAction func startButton(_ sender: Any) {
        start()
    }
    
    @IBAction func goButtonTap(_ sender: Any) {
        addMarkerPin()
    }
    
    @IBAction func clearButtonTap(_ sender: Any) {
        removeDirectionsAndMarker()
    }
}

// MARK: - CLLocationManagerDelegate
extension MainViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        checkLocationAuthoriation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Error requesting location: \(error.localizedDescription)")
    }
}
// MARK: - MKMapViewDelegate
extension MainViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        let center = getCentrLocation(mapView: mapView)
        guard let newLocation = oneLocation else { return }
        guard center.distance(from: newLocation) > 50 else { return }
        oneLocation = center
        geocoder.cancelGeocode()
        
        geocoder.reverseGeocodeLocation(center) { [weak self] (placemark, _ ) in
            guard let self = self else { return }
            guard let placemark = placemark?.first else { return }
            let streetNumber = placemark.subThoroughfare ?? ""
            let city = placemark.locality ?? ""
            let streetName = placemark.thoroughfare ?? ""
            print("\(city) \(streetName) \(streetNumber)")
            DispatchQueue.main.async {
                self.addresLabel.text = "\(city) \(streetName) \(streetNumber)"
                self.oneLocation = center
                self.titleMarker = placemark.thoroughfare
                self.cityMarker = placemark.locality
            }
        }
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(overlay: overlay)
        renderer.strokeColor = .systemBlue
        renderer.lineWidth = 4

        return renderer
    }
}

