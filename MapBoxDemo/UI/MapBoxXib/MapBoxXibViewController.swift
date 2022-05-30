//
//  MapBoxXibViewController.swift
//  MapBoxDemo
//
//  Created by gannha on 20/05/2022.
//

import UIKit
import MapboxMaps
import CoreLocation
import MapboxNavigation
import MapboxCoreNavigation
import MapboxDirections

class MapBoxXibViewController: UIViewController {
    static let SOURCE_ID = "source_id"
    @IBOutlet private weak var navigationMapView: NavigationMapView!
    @IBOutlet private weak var destination: UIButton!
    @IBOutlet private weak var removeDestination: UIButton!
    
    private var markersPoint: [(id: String, point: Point)] = [] {
        willSet {
            destination.isHidden = newValue.isEmpty
        }
    }
    
    private var mapView: MapView {
        navigationMapView.mapView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        let navigationViewportDataSource = NavigationViewportDataSource(navigationMapView.mapView, viewportDataSourceType: .raw)
        navigationViewportDataSource.followingMobileCamera.zoom = 13.0
        navigationMapView.navigationCamera.viewportDataSource = navigationViewportDataSource
        
        guard let userLocation = navigationMapView.mapView.location.latestLocation else { return }
        let camera = CameraOptions(
            center: userLocation.coordinate,
            zoom: 13)
        navigationMapView.mapView.mapboxMap.setCamera(to: camera)
    }
    
    @IBAction private func backTap(_ sender: UIButton, forEvent event: UIEvent) {
        dismiss(animated: true) {
            
        }
    }
    
    @IBAction private func mapLongPress(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .ended else { return }
        let point = Point(mapView.mapboxMap.coordinate(for: sender.location(in: mapView)))
        addMaker(at: point)
    }
    
    @IBAction private func destination(_ sender: UIButton, forEvent event: UIEvent) {
        showDestination()
        removeDestination.isHidden = false
        sender.isHidden = true
    }
    
    @IBAction func removeDestination(_ sender: UIButton, forEvent event: UIEvent) {
        hideDestination()
        sender.isHidden = true
    }
    private func addMaker(at point: Point) {
        let markerId = UUID().uuidString
        markersPoint.append((markerId, point))
        var pointAnnotation = PointAnnotation(coordinate: point.coordinates)
        pointAnnotation.image = .init(image: UIImage(named: "map-maker")!, name: "map-maker")
        let pointAnnotationManager =  mapView.annotations.makePointAnnotationManager(id: markerId, layerPosition: nil)
        pointAnnotationManager.delegate = self
        pointAnnotationManager.annotations = [pointAnnotation]
        
        pointAnnotation.image?.image.accessibilityIdentifier = markerId
    }
    
    private func addAnnotaion(at coordinate: CLLocationCoordinate2D, imageSize offsetY: CGFloat, markerId: String?) {
        var options: ViewAnnotationOptions = ViewAnnotationOptions(
            geometry: Point(coordinate),
            width: 150,
            height: 125,
//            associatedFeatureId: markerId,
            allowOverlap: true,
            anchor: .bottom
        )
        
        options.offsetY = offsetY
        let annotationView = AnnotationView()
        annotationView.title.text = String(format: "latitude = %.2f\nlongtitude = %.2f", coordinate.latitude, coordinate.longitude)
        annotationView.onClickButton = { sender, event in
            print(annotationView.title.text as Any)
        }
        do {
            try mapView.viewAnnotations.add(annotationView, options: options)
        } catch let e {
            print(e.localizedDescription)
        }
    }
    
    private func showDestination() {
        var waypoints = markersPoint.map { point -> Waypoint in
            let coordinate = point.point.coordinates
            return Waypoint(
                coordinate: CLLocationCoordinate2D(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
            )
        }
        if let userLocation = navigationMapView.mapView.location.latestLocation {
            waypoints.insert(Waypoint(location: userLocation.location, heading: userLocation.heading, name: "User Location"), at: 0)
        }
        guard !waypoints.isEmpty else { return }
        let navigationRouteOptions = NavigationRouteOptions(waypoints: waypoints)
        var southwest: CLLocationCoordinate2D? = nil
        var northeast: CLLocationCoordinate2D? = nil
        Directions.shared.calculate(navigationRouteOptions) { [weak self] session, result in
            switch result {
            case .failure(let error):
                print(error.localizedDescription)
            case .success(let response):
                self?.navigationMapView.removeRoutes()
                if let routes = response.routes,
                   let currentRoute = routes.first {
                    self?.navigationMapView.show(routes)
                    self?.navigationMapView.showWaypoints(on: currentRoute)
                    response.routes?.last?.legSeparators.forEach { waypoint in
                        guard let coordinate = waypoint?.coordinate else { return }
                        
                        if let sw = southwest {
                            if sw > coordinate {
                                southwest = coordinate
                            }
                        } else {
                            southwest = coordinate
                        }
                        if let ne = northeast {
                            if ne < coordinate {
                                northeast = coordinate
                            }
                        } else {
                            northeast = coordinate
                        }
                    }
                    guard let sw = southwest,
                          let ne = northeast,
                          var camera = self?.navigationMapView.mapView.mapboxMap.camera(
                                  for: CoordinateBounds(
                                  southwest: sw,
                                  northeast: ne
                              ), padding: .zero, bearing: 0, pitch: 0) else {
                              return
                          }
                    camera.zoom = (camera.zoom ?? 0.0) - 0.3
                    
                    self?.navigationMapView.mapView.mapboxMap.setCamera(to: camera)
                }
            }
        }
    }
    
    private func hideDestination() {
        navigationMapView.removeRoutes()
        navigationMapView.removeWaypoints()
        navigationMapView.removeRouteDurations()
        navigationMapView.removeArrow()
        
        markersPoint.forEach { markerPoint in
            mapView.annotations.removeAnnotationManager(withId: markerPoint.id)
        }
        
        mapView.viewAnnotations.removeAll()
        markersPoint.removeAll()
    }
}

extension MapBoxXibViewController: AnnotationInteractionDelegate {
    func annotationManager(_ manager: AnnotationManager, didDetectTappedAnnotations annotations: [Annotation]) {
        if let point = annotations.first as? MapboxMaps.PointAnnotation,
           let image = point.image?.image {
            guard let currentAnnotationView = mapView.viewAnnotations.view(forFeatureId: image.accessibilityIdentifier ?? "") else {
                let imageSize = point.image?.image.size.height ?? 0
                addAnnotaion(at: point.point.coordinates, imageSize: imageSize, markerId: image.accessibilityIdentifier)
                return
            }
            mapView.viewAnnotations.remove(currentAnnotationView)
        }
    }
}

private extension CLLocationCoordinate2D {
    static func >(lhs: Self, rhs: Self) -> Bool {
        (lhs.latitude, lhs.longitude) > (rhs.latitude, rhs.longitude)
    }
    
    static func >=(lhs: Self, rhs: Self) -> Bool {
        (lhs.latitude, lhs.longitude) >= (rhs.latitude, rhs.longitude)
    }
    
    static func <(lhs: Self, rhs: Self) -> Bool {
        (lhs.latitude, lhs.longitude) < (rhs.latitude, rhs.longitude)
    }
    
    static func <=(lhs: Self, rhs: Self) -> Bool {
        (lhs.latitude, lhs.longitude) <= (rhs.latitude, rhs.longitude)
    }
}
