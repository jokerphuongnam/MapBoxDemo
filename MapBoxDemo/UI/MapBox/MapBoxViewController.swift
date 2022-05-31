//
//  MapBoxViewController.swift
//  MapBoxDemo
//
//  Created by gannha on 20/05/2022.
//

import UIKit
import MapboxCoreNavigation
import MapboxNavigation
import MapboxDirections
import MapboxMaps
import MapKit

final class MapBoxViewController: UIViewController {
    let origin = CLLocationCoordinate2D(latitude: 10.7896748, longitude: 106.7006882)
    let destination = CLLocationCoordinate2D(latitude: 10.8405889, longitude: 106.8129073)
    let vinhome = CLLocationCoordinate2D(latitude: 10.8399029, longitude: 106.832786)
    
    private lazy var nextButton: UIButton = {
        let button = UIButton()
        button.setTitle("To xib VC", for: .normal)
        button.configuration = .tinted()
        button.addTarget(self, action: #selector(nextButtonTap), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    private lazy var destinationButton: UIButton = {
        let button = UIButton()
        button.setTitle("Destination", for: .normal)
        button.configuration = .tinted()
        button.addTarget(self, action: #selector(destinationTap), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    private lazy var navigationMapView: NavigationMapView = {
        let navigationMapView = NavigationMapView(frame: view.bounds)
        navigationMapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        navigationMapView.delegate = self
        let mapLongGesture = UILongPressGestureRecognizer()
        mapLongGesture.addTarget(self, action: #selector(mapLongPress))
//        mapView.addGestureRecognizer(mapLongGesture)
        let mapPanGesture = UIPanGestureRecognizer()
        mapPanGesture.addTarget(self, action:  #selector(mapPan))
        navigationMapView.gestureRecognizers = [
            mapLongGesture
        ]
//        navigationMapView.mapView.gestureRecognizers = [
//            mapPanGesture
//        ]
        return navigationMapView
    }()
    private var markerId = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(navigationMapView)
        view.addSubview(nextButton)
        view.addSubview(destinationButton)
        NSLayoutConstraint.activate([
            nextButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32),
            nextButton.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor)
        ])
        NSLayoutConstraint.activate([
            destinationButton.bottomAnchor.constraint(equalTo: nextButton.topAnchor, constant: -32),
            destinationButton.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor)
        ])
        let navigationViewportDataSource = NavigationViewportDataSource(navigationMapView.mapView, viewportDataSourceType: .raw)
        navigationViewportDataSource.followingMobileCamera.zoom = 13.0
        navigationMapView.navigationCamera.viewportDataSource = navigationViewportDataSource
        
        nextButtonTap()
    }
}

private extension MapBoxViewController {
    func calculateRoute(from originCoordinate: CLLocationCoordinate2D,to destinationCoordinate: CLLocationCoordinate2D) {
        let origin = Waypoint(coordinate: originCoordinate, name: "Start")
        
        let destination = Waypoint(coordinate: destinationCoordinate, name: "Finish")
        
        let navigationRouteOptions = NavigationRouteOptions(waypoints: [origin, destination])
        
        Directions.shared.calculate(navigationRouteOptions) { [weak self] session, result in
            switch result {
            case .failure(let error):
                print(error.localizedDescription)
            case .success(let response):
                self?.navigationMapView.removeRoutes()
                if let routes = response.routes,
                   let currentRoute = routes.first,
                   var camera = self?.navigationMapView.mapView.mapboxMap.camera(
                    for: CoordinateBounds(
                    southwest: originCoordinate,
                    northeast: destinationCoordinate
                ), padding: .zero, bearing: 0, pitch: 0) {
                    self?.navigationMapView.show(routes)
                    self?.navigationMapView.showWaypoints(on: currentRoute)
                    
                    camera.zoom = (camera.zoom ?? 0.0) - 0.3
                    
                    self?.navigationMapView.mapView.mapboxMap.setCamera(to: camera)
                }
            }
        }
    }
    
    func addMaker(at point: Point) {
        var pointAnnotation = PointAnnotation(coordinate: point.coordinates)
        pointAnnotation.image = .init(image: UIImage(named: "map-maker")!, name: "map-maker")
        let pointAnnotationManager =  navigationMapView.mapView.annotations.makePointAnnotationManager()
        pointAnnotationManager.delegate = self
        pointAnnotationManager.annotations = [pointAnnotation]
        
        let markerId = UUID().uuidString
        pointAnnotation.image?.image.accessibilityIdentifier = markerId
    }
}

private extension MapBoxViewController {
    @objc func nextButtonTap() {
        let vc = MapBoxXibViewController()
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true) {
            
        }
    }
    
    @objc func destinationTap() {
        calculateRoute(from: origin ,to: vinhome)
    }
    
    @objc func mapLongPress(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .ended else { return }
        let point = Point(navigationMapView.mapView.mapboxMap.coordinate(for: sender.location(in: navigationMapView)))
        addMaker(at: point)
    }
    
    @objc func mapPan(_ sender: UIPanGestureRecognizer) {
        let point = Point(navigationMapView.mapView.mapboxMap.coordinate(for: sender.location(in: navigationMapView)))
        guard sender.state == .ended else {
            let coordinate = point.coordinates
            navigationMapView.mapView.mapboxMap.setCamera(to: .init(center: .init(latitude: coordinate.latitude, longitude: coordinate.longitude)))
            return
        }
//        addMaker(at: point)
        print("\(point)")
    }
}

extension MapBoxViewController: NavigationMapViewDelegate {
    
}

extension MapBoxViewController: AnnotationInteractionDelegate {
    func annotationManager(_ manager: AnnotationManager, didDetectTappedAnnotations annotations: [Annotation]) {
        if let point = annotations.first as? MapboxMaps.PointAnnotation,
           let image = point.image?.image {
            guard let currentAnnotationView = navigationMapView.mapView.viewAnnotations.view(forFeatureId: image.accessibilityIdentifier ?? "") else {
//                let imageSize = point.image?.image.size.height ?? 0
//                addAnnotaion(at: point.point.coordinates, imageSize: imageSize, markerId: image.accessibilityIdentifier)
                return
            }
            navigationMapView.mapView.viewAnnotations.remove(currentAnnotationView)
        }
    }
}
