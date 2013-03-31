/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 *  JAPulldownTableViewController.m
 *
 *  Copyright (c) 2013 Josh Avant
 *
 *  Permission is hereby granted, free of charge, to any person obtaining a
 *  copy of this software and associated documentation files (the "Software"),
 *  to deal in the Software without restriction, including without limitation
 *  the rights to use, copy, modify, merge, publish, distribute, sublicense,
 *  and/or sell copies of the Software, and to permit persons to whom the
 *  Software is furnished to do so, subject to the following conditions:
 *
 *  The above copyright notice and this permission notice shall be included in
 *  all copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 *  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 *  DEALINGS IN THE SOFTWARE.
 *
 *  If we meet some day, and you think this stuff is worth it, you can buy me a
 *  beer in return.
 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

#import "JAPulldownTableViewController.h"
#import "JAConstants.h"
#import "JAMaskedBackgroundView.h"
#import "JATouchPassingTableView.h"
#import <MapKit/MapKit.h>
#import <QuartzCore/QuartzCore.h>

@interface JAPulldownTableViewController () <UITableViewDelegate, UITableViewDataSource>

@property(nonatomic) JATouchPassingTableView  *tableView;
@property(nonatomic) JAMaskedBackgroundView   *maskedBackgroundView;
@property(nonatomic) MKMapView                *mapView;
@property(nonatomic) UISwipeGestureRecognizer *maximizeGestureRecognizer;
@property(nonatomic) UIView                   *gestureRecognizerView;
@property(nonatomic) BOOL                     userIsTouchingTableView;
@property(nonatomic) BOOL                     tableViewIsMinimzed;

// configures mapView to display the desired map region in the headline area of mapView's frame
-    (void)configureMapView:(MKMapView *)mapView
  forHeadlineRegionOfHeight:(CGFloat)height
                 withCenter:(CLLocationCoordinate2D)center
        latitudinalDistance:(CLLocationDistance)latitudinalDistance
       longitudinalDistance:(CLLocationDistance)longitudinalDistance;

- (MKCoordinateRegion)regionForCenter:(CLLocationCoordinate2D)center
                  latitudinalDistance:(CLLocationDistance)latitudinalDistance
                 longitudinalDistance:(CLLocationDistance)longitudinalDistance;

// takes a contentOffset and calculates an opacity value for a linear fade over `range`
- (float)opacityForContentOffset:(CGFloat)contentOffset overRange:(NSRange)range;

- (void)minimizeTableView;
- (void)maximizeTableView;

@end

@implementation JAPulldownTableViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if(self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        self.tableView = [[JATouchPassingTableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        self.tableView.delegate       = self;
        self.tableView.dataSource     = self;
        
        self.mapView = [[MKMapView alloc] initWithFrame:CGRectZero];
        
        self.maskedBackgroundView = [[JAMaskedBackgroundView alloc] initWithFrame:CGRectZero];
        
        self.maximizeGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(maximizeTableView)];
        self.maximizeGestureRecognizer.direction = UISwipeGestureRecognizerDirectionUp;
        
        self.gestureRecognizerView = [[UIView alloc] initWithFrame:CGRectZero];
        self.gestureRecognizerView.backgroundColor = [UIColor clearColor];
        
        self.userIsTouchingTableView = NO;
        self.tableViewIsMinimzed     = NO;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    CGRect fullWindow = CGRectMake(0.f, 0.f, CGRectGetWidth(self.view.bounds), CGRectGetHeight(self.view.bounds));
    
    self.tableView.frame = fullWindow;
    self.tableView.contentInset = UIEdgeInsetsMake(kJAHeadlineViewHeight, 0, 0, 0);
    self.tableView.backgroundView = self.maskedBackgroundView;
    self.tableView.backgroundColor = [UIColor clearColor];
    
    self.maskedBackgroundView.maskView.backgroundColor = [UIColor whiteColor];
    self.maskedBackgroundView.maskYOffset = kJAHeadlineViewHeight;

    self.mapView.frame = fullWindow;
    
    [self.view addSubview:self.mapView];
    [self.view addSubview:self.tableView];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self configureMapView:self.mapView
 forHeadlineRegionOfHeight:kJAHeadlineViewHeight
                withCenter:CLLocationCoordinate2DMake(37.756000, -122.350249)
       latitudinalDistance:51071
      longitudinalDistance:29822];
}

#pragma mark - Private Methods
-    (void)configureMapView:(MKMapView *)mapView
  forHeadlineRegionOfHeight:(CGFloat)headlineHeight
                 withCenter:(CLLocationCoordinate2D)center
        latitudinalDistance:(CLLocationDistance)latitudinalDistance
       longitudinalDistance:(CLLocationDistance)longitudinalDistance
{
    if(headlineHeight > CGRectGetHeight(mapView.frame)) return;
    
    MKCoordinateRegion headlineRegion = [self regionForCenter:center
                                          latitudinalDistance:latitudinalDistance
                                         longitudinalDistance:longitudinalDistance];
    
    mapView.region = headlineRegion;
    
    double mapRectHeight = MKMapRectGetHeight(mapView.visibleMapRect);
    CGFloat headlineHeightFactor = headlineHeight / CGRectGetHeight(mapView.frame);
    double mapOffset = (double)headlineHeightFactor * mapRectHeight;
    MKMapRect headlineMapRect = MKMapRectOffset(mapView.visibleMapRect, 0, (mapRectHeight - mapOffset) / 2);
    
    mapView.visibleMapRect = headlineMapRect;
}

- (MKCoordinateRegion)regionForCenter:(CLLocationCoordinate2D)center
                  latitudinalDistance:(CLLocationDistance)latitudinalDistance
                 longitudinalDistance:(CLLocationDistance)longitudinalDistance
{
    const double metersPerDegree = 111000.0;
    MKCoordinateSpan span = MKCoordinateSpanMake(latitudinalDistance / metersPerDegree,
                                                 longitudinalDistance / (metersPerDegree * cos(center.latitude * M_PI / 180.0)));
    return MKCoordinateRegionMake(center, span);
}

- (float)opacityForContentOffset:(CGFloat)contentOffset overRange:(NSRange)range
{    
    static float maxFade = 0.7;
    
    if(contentOffset < range.location)
    {
        return 1.f;
    }
    else if(contentOffset > range.location + range.length)
    {
        return maxFade;
    }
    else
    {
        return 1 - (1 - maxFade) * ((contentOffset - range.location) / range.length);
    }
}

- (void)minimizeTableView
{
    self.tableViewIsMinimzed = YES;
    self.tableView.userInteractionEnabled = NO;
    self.tableView.showsVerticalScrollIndicator = NO;
    
    CGRect minimizedFrame = self.tableView.frame;
    minimizedFrame.origin.y = CGRectGetHeight(self.view.bounds) - kJAHeadlineViewHeight - kJAMinimizedVisibleTopHeight;
    
    self.gestureRecognizerView.frame = CGRectMake(0.f,
                                                  CGRectGetMinY(minimizedFrame) + kJAHeadlineViewHeight,
                                                  CGRectGetWidth(minimizedFrame),
                                                  kJAMinimizedVisibleTopHeight);
    
    [UIView animateWithDuration:kJATableViewAnimationSpeed
                          delay:0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         self.tableView.frame = minimizedFrame;
                     }
                     completion:^(BOOL finished) {
                         [self.view addSubview:self.gestureRecognizerView];
                         [self.gestureRecognizerView addGestureRecognizer:self.maximizeGestureRecognizer];
                     }];
}

- (void)maximizeTableView
{
    CGRect maximizedFrame = self.tableView.frame;
    maximizedFrame.origin.y = 0;
    
    [UIView animateWithDuration:kJATableViewAnimationSpeed / 1.3
                          delay:0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         self.tableView.frame = maximizedFrame;
                         self.tableView.layer.opacity = 1.f;
                     }
                     completion:^(BOOL finished) {
                         [self.gestureRecognizerView removeFromSuperview];
                         
                         self.tableView.userInteractionEnabled = YES;
                         self.tableView.showsVerticalScrollIndicator = YES;
                         self.tableViewIsMinimzed = NO;
                     }];
}

#pragma mark - UIScrollViewDelegate
- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if(self.tableView.contentOffset.y <= 0)
    {
        // scrollView is scrolling within inset height
        self.maskedBackgroundView.maskYOffset = fabs(self.tableView.contentOffset.y);
        
        if(self.tableView.contentOffset.y < -1 * kJAHeadlineViewHeight)
        {
            // scrollView is scrolling below inset height ('pulling down' region)
            NSUInteger fadeStartOffset  = 215;
            NSUInteger fadeOffsetLength = 70;
            
            if((self.userIsTouchingTableView || self.tableView.layer.opacity != 1) && !self.tableViewIsMinimzed)
            {
                self.tableView.layer.opacity = [self opacityForContentOffset:fabs(self.tableView.contentOffset.y)
                                                                   overRange:NSMakeRange(fadeStartOffset, fadeOffsetLength)];
            }

            if(self.userIsTouchingTableView && self.tableView.contentOffset.y < -1 * (CGFloat)(fadeStartOffset + fadeOffsetLength))
            {
                // scrollView is being pulled down by the user + the contentOffset has reached the end of fading
                [self minimizeTableView];
            }
        }
    }
    else
    {
        // scrollView has scrolled past inset height
        self.maskedBackgroundView.maskYOffset = 0;
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    self.userIsTouchingTableView = YES;
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    self.userIsTouchingTableView = NO;
}

#pragma mark - UITableViewDelegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 20;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *reuseIdentifier = @"HiMom";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    if(cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    }
    cell.textLabel.text = @"Foo";
    cell.backgroundColor = [UIColor whiteColor];
    
    
    return cell;
}

@end
