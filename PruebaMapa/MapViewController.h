//
//  ViewController.h
//  PruebaMapa
//
//  Created by Javier Moreno on 17/05/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Mapkit/Mapkit.h>

@interface MapViewController : UIViewController <MKMapViewDelegate>

@property (strong, nonatomic) IBOutlet MKMapView *mapView;
@property (nonatomic, strong) MKPolyline *routeLine;
@property (nonatomic, strong) MKPolylineView *routeLineView;
@property (nonatomic, strong) NSString *origin;
@property (nonatomic, strong) NSString *destination;

@end
