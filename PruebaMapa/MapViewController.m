//
//  ViewController.m
//  PruebaMapa
//
//  Created by Javier Moreno on 17/05/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MapViewController.h"


@interface MapViewController ()
{
    MKMapRect _routeRect;
}

@property (strong, nonatomic) NSMutableData *receivedData;

@end

@implementation MapViewController
@synthesize mapView = _mapView;
@synthesize routeLine = _routeLine;
@synthesize routeLineView = _routeLineView;
@synthesize origin = _origin;
@synthesize destination = _destination;
@synthesize receivedData = _receivedData;

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    // Create the request.
    
    NSString *urlPath = [NSString stringWithFormat:@"http://maps.googleapis.com/maps/api/directions/json?origin=%@&destination=%@&sensor=false", _origin, _destination];
    urlPath = [urlPath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    NSURLRequest *theRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:urlPath]
                                                cachePolicy:NSURLRequestUseProtocolCachePolicy
                                            timeoutInterval:60.0];
    // create the connection with the request
    // and start loading the data
    NSURLConnection *theConnection=[[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
    if (theConnection) {
        // Create the NSMutableData to hold the received data.
        // receivedData is an instance variable declared elsewhere.
        _receivedData = [[NSMutableData alloc] initWithLength:0];
    } else {
        // Inform the user that the connection failed.
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    // This method is called when the server has determined that it
    // has enough information to create the NSURLResponse.
    
    // It can be called multiple times, for example in the case of a
    // redirect, so each time we reset the data.
    
    // receivedData is an instance variable declared elsewhere.
    [_receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    // Append the new data to receivedData.
    // receivedData is an instance variable declared elsewhere.
    [_receivedData appendData:data];
}

- (void)connection:(NSURLConnection *)connection
  didFailWithError:(NSError *)error
{
    // receivedData is declared as a method instance elsewhere
    [_receivedData setLength:0];
    
    // inform the user
    NSLog(@"Connection failed! Error - %@ %@",
          [error localizedDescription],
          [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    // do something with the data
    // receivedData is declared as a method instance elsewhere
    NSLog(@"Succeeded! Received %d bytes of data",[_receivedData length]);
    
    NSString *decodingPoints = [self encodedPointsFromGoogleapisData];

    NSMutableArray *decoding = [self decodePolyline:decodingPoints];
    
    // create the overlay
    [self loadRouteFromWaypoints:decoding];
    
    // add the overlay to the map
    if (nil != self.routeLine) {
        [self.mapView addOverlay:self.routeLine];
    }
    
    [self.mapView setVisibleMapRect:_routeRect];
    
    [_receivedData setLength:0];
}

- (NSString *)encodedPointsFromGoogleapisData
{
    NSError *error = nil;
    NSMutableDictionary *jsonArray = [NSJSONSerialization JSONObjectWithData:_receivedData options:NSJSONReadingMutableContainers error: &error];

    if (!jsonArray) {
        NSLog(@"Error parsing JSON: %@", error);
        NSLog(@"_receivedData: %@", [_receivedData description]);
    } else {
        if (![[jsonArray valueForKey:@"status"] isEqualToString:@"ZERO_RESULTS"]) {
            NSDictionary *routes = [[jsonArray valueForKey:@"routes"] objectAtIndex:0];
            NSDictionary *overviewPolyline = [routes valueForKey:@"overview_polyline"];
            return [overviewPolyline valueForKey:@"points"];
        }            
    }
    
    return nil;
    
}

- (NSMutableArray *) decodePolyline:(NSString *)encodedPoints {
    NSString *escapedEncodedPoints = [encodedPoints stringByReplacingOccurrencesOfString:@"\\\\" withString:@"\\"];
    int len = [escapedEncodedPoints length];
    NSMutableArray *waypoints = [[NSMutableArray alloc] init];
    int index = 0;
    float lat = 0;
    float lng = 0;
    
    while (index < len) {
        char b;
        int shift = 0;
        int result = 0;
        do {
            b = [escapedEncodedPoints characterAtIndex:index++] - 63;
            result |= (b & 0x1f) << shift;
            shift += 5;
        } while (b >= 0x20);
        
        float dlat = ((result & 1) ? ~(result >> 1) : (result >> 1));
        lat += dlat;
        
        shift = 0;
        result = 0;
        do {
            b = [escapedEncodedPoints characterAtIndex:index++] - 63;
            result |= (b & 0x1f) << shift;
            shift += 5;
        } while (b >= 0x20);
        
        float dlng = ((result & 1) ? ~(result >> 1) : (result >> 1));
        lng += dlng;
        
        NSNumber *latitude = [[NSNumber alloc] initWithFloat:lat * 1e-5];  
        NSNumber *longitude = [[NSNumber alloc] initWithFloat:lng * 1e-5];  
        CLLocation *loc = [[CLLocation alloc] initWithLatitude:[latitude floatValue] longitude:[longitude floatValue]]; 
        [waypoints addObject:loc];
    }
    return waypoints;
}

-(void)loadRouteFromWaypoints:(NSArray *)waypoints
{    
    // while we create the route points, we will also be calculating the bounding box of our route
    // so we can easily zoom in on it.
    MKMapPoint northEastPoint;
    MKMapPoint southWestPoint;
    
    // create a c array of points.
    MKMapPoint* pointArr = malloc(sizeof(CLLocationCoordinate2D) * waypoints.count);
    
    for(int idx = 0; idx < waypoints.count; idx++)
    {
        //
        CLLocation *location = [waypoints objectAtIndex:idx];
        
        // create our coordinate and add it to the correct spot in the array
        CLLocationCoordinate2D coordinate = location.coordinate;
        
        MKMapPoint point = MKMapPointForCoordinate(coordinate);
        
        //
        // adjust the bounding box
        //
        
        // if it is the first point, just use them, since we have nothing to compare to yet.
        if (idx == 0) {
            northEastPoint = point;
            southWestPoint = point;
        }
        else
        {
            if (point.x > northEastPoint.x)
                northEastPoint.x = point.x;
            if(point.y > northEastPoint.y)
                northEastPoint.y = point.y;
            if (point.x < southWestPoint.x)
                southWestPoint.x = point.x;
            if (point.y < southWestPoint.y)
                southWestPoint.y = point.y;
        }
        
        pointArr[idx] = point;
                
    }
    
    // create the polyline based on the array of points.
    self.routeLine = [MKPolyline polylineWithPoints:pointArr count:waypoints.count];
    
    _routeRect = MKMapRectMake(southWestPoint.x, southWestPoint.y, northEastPoint.x - southWestPoint.x, northEastPoint.y - southWestPoint.y);
    
    // clear the memory allocated earlier for the points
    free(pointArr);
    
}

- (MKOverlayView *)mapView:(MKMapView *)mapView viewForOverlay:(id )overlay
{
    MKOverlayView* overlayView = nil;
    
    if(overlay == self.routeLine)
    {
        //if we have not yet created an overlay view for this overlay, create it now.
        if(nil == self.routeLineView)
        {
            self.routeLineView = [[MKPolylineView alloc] initWithPolyline:self.routeLine];
            self.routeLineView.fillColor = [UIColor colorWithRed:1.0f green:0.0f blue:0.0f alpha:0.5f];
            self.routeLineView.strokeColor = [UIColor colorWithRed:1.0f green:0.0f blue:0.0f alpha:0.5f];
            self.routeLineView.lineWidth = 5;
        }
        
        overlayView = self.routeLineView;
        
    }
    
    return overlayView;
    
}

- (void)viewDidUnload
{
    [self setMapView:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

@end
