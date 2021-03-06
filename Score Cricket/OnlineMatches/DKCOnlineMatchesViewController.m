//
//  DKCOnlineMatchesTableViewController.m
//  Score Cricket
//
//  Created by Dinesh Challa on 5/16/14.
//
//

#import "DKCOnlineMatchesViewController.h"
#import "DKCCreatePlist.h"
#import "DKCScoringViewController.h"
#import "DKCScoreCardViewController.h"
#import "DKCListOfMatchesCell.h"
#import <QuartzCore/QuartzCore.h>
#import "UIImage+StackBlur.h"
#import <Parse/Parse.h>
#import "DKCScoreTableViewCell.h"
#import "DIDatepicker.h"
#import "DKCBackgroundImage.h"
#import "BOZPongRefreshControl.h"
#import "GADBannerView.h"
#import "DKCHeader.h"


@interface DKCOnlineMatchesViewController (){
	NSIndexPath *_cellIndexPath;
}
@property (nonatomic, retain) NSMutableArray *tableData;
@property (strong, nonatomic) DIDatepicker *datepicker;
@property (nonatomic) BOOL fetched;
@property (strong, nonatomic) BOZPongRefreshControl* pongRefreshControl;
@property (nonatomic) BOOL bannerIsVisible;
@property (nonatomic) BOOL isGADbannerVisible;
@property (nonatomic, strong) GADBannerView *gadBannerView;
@property (nonatomic, strong) ADBannerView *bannerView;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@end

@implementation DKCOnlineMatchesViewController


- (NSDateFormatter *)dateFormatter
{
	if (!_dateFormatter)
	{
		_dateFormatter = [[NSDateFormatter alloc] init];
		[_dateFormatter setDateFormat:DKC_DATE_NAV_DATE_FORMAT_STRING];
	}
	return _dateFormatter;
}

- (void)viewDidLayoutSubviews
{
	[super viewDidLayoutSubviews];
    self.pongRefreshControl = [BOZPongRefreshControl attachToTableView:self.tableView
                                                     withRefreshTarget:self
                                                      andRefreshAction:@selector(refreshTriggered)];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	[self.pongRefreshControl finishedLoading];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	self.datepicker = [[DIDatepicker alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 50)];
	[self.datepicker addTarget:self action:@selector(updateSelectedDate) forControlEvents:UIControlEventValueChanged];
	[self.datepicker fillCurrentYear];
	[self.datepicker selectDate:[NSDate date]];
	
	[self.tableView registerClass:[DKCScoreTableViewCell class] forCellReuseIdentifier:@"ScoreCell"];
	[self.tableView registerNib:[UINib nibWithNibName:@"DKCScoreTableViewCell" bundle:[NSBundle mainBundle]] forCellReuseIdentifier:@"ScoreCell"];
    
	[self updateSelectedDate];
	
    [self.tableView setBackgroundView:[[UIImageView alloc] initWithImage:[DKCBackgroundImage backgroundImage]]];
    self.tableView.backgroundView.frame = self.tableView.frame;
    self.tableView.backgroundColor = [UIColor clearColor];
    
    self.navigationController.navigationBarHidden = NO;
    self.tableView.separatorColor = [UIColor blackColor];
    
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
	ADBannerView *banner = self.bannerView;
	self.bannerIsVisible = NO;
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	if (self.isLive)
	{
		self.title = @"Live Scores";
	}
	else
	{
		self.title = @"Results";
	}
	
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	[self.tableView reloadData];
}

- (void)updateSelectedDate
{
	__weak DKCOnlineMatchesViewController *wSelf = self;
	
	NSDate *date = [NSDate date];
	if (self.datepicker.selectedDate)
	{
		date = self.datepicker.selectedDate;
	}
	else
	{
		NSCalendar *calendar = [NSCalendar currentCalendar];
		NSDateComponents *todayComponents = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:date];
		date = [calendar dateFromComponents:todayComponents];
	}
	//NSPredicate *predicate = [NSPredicate predicateWithFormat:
							 // @"DatePickerStartDate = %@",date];
	
	self.fetched = NO;
	[self.tableView reloadData];
	
	PFQuery *dateQuery = [PFQuery queryWithClassName:DKC_PROD_MATCHES];
	[dateQuery whereKey:@"DatePickerStartDate" equalTo:date];
	
	PFQuery *dateStringQuery = [PFQuery queryWithClassName:DKC_PROD_MATCHES];
	[dateStringQuery whereKey:@"DatePickerStartDateString" equalTo:[self.dateFormatter stringFromDate:date]];
	
	PFQuery *query = [PFQuery orQueryWithSubqueries:@[dateQuery,dateStringQuery]];
	if (self.isLive)
	{
		[query whereKey:@"isCurrent" equalTo:@"current"];
	}
	else
	{
		[query whereKey:@"isCurrent" equalTo:@"completed"];
	}
	[query whereKey:@"Team1" notEqualTo:@"Team 1"];
	[query whereKey:@"Team2" notEqualTo:@"Team 2"];
	[query selectKeys:@[@"Team1", @"Team2", @"Team2Score", @"Team1Score", @"Team2Balls", @"Team1Balls", @"Status",@"FileName",@"isCurrent",@"MatchStartDate"]];
	[query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
		wSelf.fetched = YES;
		[wSelf.pongRefreshControl performSelector:@selector(finishedLoading) withObject:nil afterDelay:0.8];
		if (!error) {
			// The find succeeded.
			NSLog(@"Successfully retrieved %d scores.", objects.count);
			wSelf.tableData = [objects mutableCopy];
			[wSelf.tableView reloadData];
			
		} else {
			// Log details of the failure
			NSLog(@"Error: %@ %@", error, [error userInfo]);
			wSelf.tableData = nil;
			[wSelf.tableView reloadData];
		}
	}];
	
	if (self.isLive)
	{
		// May return nil if a tracker has not already been initialized with a
		// property ID.
		id tracker = [[GAI sharedInstance] defaultTracker];
		
		// This screen name value will remain set on the tracker and sent with
		// hits until it is set to a new value or to nil.
		[tracker set:kGAIScreenName
			   value:@"Live Scores"];
		
		[tracker send:[[GAIDictionaryBuilder createAppView] build]];
	}
	else
	{
		// May return nil if a tracker has not already been initialized with a
		// property ID.
		id tracker = [[GAI sharedInstance] defaultTracker];
		
		// This screen name value will remain set on the tracker and sent with
		// hits until it is set to a new value or to nil.
		[tracker set:kGAIScreenName
			   value:@"Results"];
		
		[tracker send:[[GAIDictionaryBuilder createAppView] build]];
	}
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
	return 50;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
	return self.datepicker;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
	if (self.fetched && [self.tableData count] == 0)
	{
		return 100;
	}
	else
	{
		return 0;
	}
	
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
	
	UIView *view = [UIView new];
	view.backgroundColor = [UIColor clearColor];
	UILabel *label = [[UILabel alloc] init];
	label.frame = view.bounds;
	label.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
	label.textColor = [UIColor whiteColor];
	label.textAlignment = NSTextAlignmentCenter;
	label.text = @"No Matches Available";
	[view addSubview:label];
	return view;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return [self.tableData count];
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 70;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"ScoreCell";
    DKCScoreTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    cell.backgroundCellView.alpha = 1.0;
    NSString *Team1 = [[self.tableData objectAtIndex:[indexPath row]] objectForKey:@"Team1"];
    NSString *Team2 = [[self.tableData objectAtIndex:[indexPath row]] objectForKey:@"Team2"];
	cell.team1Name.text = Team1;
	cell.team2Name.text = Team2;
    cell.bottomLabel.text = [[self.tableData objectAtIndex:[indexPath row]] objectForKey:@"FileName"];
	if ([self.tableData[indexPath.row][@"Team1Score"] intValue] == 0 && [self.tableData[indexPath.row][@"Team1Balls"] floatValue] == 0)
	{
		cell.team1ScoreLabel.text = @"DNB";
	}
	else
	{
		int balls = [self.tableData[indexPath.row][@"Team1Balls"] intValue];
		float overs = ((balls/6)+((balls%6)/10.0f));
		cell.team1ScoreLabel.text = [NSString stringWithFormat:@"%d(%.1f)",[self.tableData[indexPath.row][@"Team1Score"] intValue],overs];
	}
    
	if ([self.tableData[indexPath.row][@"Team2Score"] intValue] == 0 && [self.tableData[indexPath.row][@"Team2Balls"] floatValue] == 0)
	{
		cell.team2ScoreLabel.text = @"DNB";
	}
	else
	{
		int balls = [self.tableData[indexPath.row][@"Team2Balls"] intValue];
		float overs = ((balls/6)+((balls%6)/10.0f));
		cell.team2ScoreLabel.text = [NSString stringWithFormat:@"%d(%.1f)",[self.tableData[indexPath.row][@"Team2Score"] intValue],overs];
	}
	
    return cell;
}

#pragma mark - Table view delegate
#define delay 0.1
#define animationDuration 1
#define animationAmplitude 5


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    DKCScoreTableViewCell *cell = (DKCScoreTableViewCell *) [tableView cellForRowAtIndexPath:indexPath];
    if (cell.frame.size.width != self.view.frame.size.width)
    {
        return;
    }
    _cellIndexPath = indexPath;
    cell.backgroundCellView.backgroundColor = [UIColor colorWithRed:0/255.0 green:0/255.0 blue:0/255.0 alpha:0.7];
    [self bounceView:cell amplitude:animationAmplitude duration:animationDuration delegate:YES];
    for (int i =1; i<=4; i++)
    {
        if (indexPath.row - i >= 0)
        {
            DKCScoreTableViewCell *tempCell = (DKCScoreTableViewCell *) [tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:indexPath.row - i inSection:0]];
            if (tempCell)
            {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay * (i + 1) * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    CGFloat modifier = 1 / (1.f * i + 1);
                    modifier = powf(modifier, i);
                    CGFloat subAmplitude = animationAmplitude * modifier;
                    [self bounceView:tempCell amplitude:subAmplitude duration:animationDuration delegate:NO];
                });
            }
        }
        if (indexPath.row + i <= [self.tableData count])
        {
            DKCListOfMatchesCell *tempCell = (DKCListOfMatchesCell *) [tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:indexPath.row + i inSection:0]];
            if (tempCell)
            {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay * (i + 1) * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    CGFloat modifier = 1 / (1.f * i + 1);
                    modifier = powf(modifier, i);
                    CGFloat subAmplitude = 5 * modifier;
                    [self bounceView:tempCell amplitude:subAmplitude duration:animationDuration delegate:NO];
                });
            }
        }
    }
	[self openScoreCard];
    
}

#define DEGREES(rads) rads * M_PI / 180.f
- (void)bounceView:(UIView *)view amplitude:(CGFloat)amplitude duration:(CGFloat)duration delegate:(BOOL)getDelegateCall {
    CGRect tempFrame = view.frame;
    tempFrame.size.width = self.view.frame.size.width * 2;
    view.frame = tempFrame;
    CGFloat m34 = 1 / 50.f* (view.layer.anchorPoint.x == 0 ? -1 : 1);
    CGFloat bounceAngleModifiers[] = {1, 0.33f, 0.13f};
    NSInteger bouncesCount = sizeof(bounceAngleModifiers) / sizeof(CGFloat);
    bouncesCount = bouncesCount * 2 + 1;
    
    CATransform3D transform = CATransform3DIdentity;
    transform.m34 = m34;
    view.layer.transform = transform;
    
    CAKeyframeAnimation *bounceKeyframe = [CAKeyframeAnimation animationWithKeyPath:@"transform.rotation.y"];
    bounceKeyframe.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    bounceKeyframe.duration = duration;
    
    NSMutableArray *bounceValues = [NSMutableArray array];
    for (NSInteger i = 0; i < bouncesCount; i++) {
        CGFloat angle = 0;
        if (i % 2 > 0) {
            angle = bounceAngleModifiers[i / 2] * amplitude;
        }
        [bounceValues addObject:@(DEGREES(angle))];
    }
    bounceKeyframe.values = bounceValues;
    if (getDelegateCall)
    {
        bounceKeyframe.delegate = self;
    }
    
    [view.layer setValue:@(0) forKeyPath:bounceKeyframe.keyPath];
    [view.layer addAnimation:bounceKeyframe forKey:nil];
}

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag
{
	DKCScoreTableViewCell *cell = (DKCScoreTableViewCell *) [self.tableView cellForRowAtIndexPath:_cellIndexPath];
	CGRect tempFrame = cell.frame;
    tempFrame.size.width = self.view.frame.size.width;
    cell.frame = tempFrame;
	cell.backgroundCellView.backgroundColor = [UIColor colorWithRed:0/255.0 green:0/255.0 blue:0/255.0 alpha:0.4];
}

- (void)openScoreCard
{
	PFObject *object = self.tableData[_cellIndexPath.row];
	[object fetchIfNeededInBackgroundWithBlock:^(PFObject *object, NSError *error) {
		if (!object|| error)
		{
			return ;
		}
		
		DKCScoreCardViewController *scoreCard = [self.storyboard instantiateViewControllerWithIdentifier:@"ScoreCardViewController"];
		scoreCard.MatchData = object[@"MatchData"];
        scoreCard.currentInnings = @"FirstInnings";
		scoreCard.isLive = YES;
        self.title = @"Back";
        [self.navigationController pushViewController:scoreCard animated:YES];
	}];
}

#pragma mark - Notifying the pong refresh control of scrolling

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self.pongRefreshControl scrollViewDidScroll];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    [self.pongRefreshControl scrollViewDidEndDragging];
}

#pragma mark - Listening for the user to trigger a refresh

- (void)refreshTriggered
{
	[self updateSelectedDate];
}


#pragma mark ads

- (GADBannerView *)gadBannerView
{
	if (!_gadBannerView)
	{
		_gadBannerView = [[GADBannerView alloc] initWithAdSize:kGADAdSizeBanner];
		_gadBannerView.adUnitID = GAD_BANNER_UNIT_ID;
		_gadBannerView.rootViewController = self;
		_gadBannerView.frame = CGRectMake(0, self.view.frame.size.height - _gadBannerView.frame.size.height, self.view.frame.size.width, _gadBannerView.frame.size.height);
		_gadBannerView.delegate = self;
		[self.view addSubview:_gadBannerView];
	}
	return _gadBannerView;
}

- (ADBannerView *)bannerView
{
	if (!_bannerView)
	{
		_bannerView = [[ADBannerView alloc] init];
		_bannerView.frame = CGRectMake(0, self.view.frame.size.height, self.view.frame.size.width, _bannerView.frame.size.height);
		_bannerView.delegate = self;
		[self.view addSubview:_bannerView];
	}
	return _bannerView;
}

- (void)bannerViewDidLoadAd:(ADBannerView *)banner
{
	
    if (!self.bannerIsVisible)
    {
		[self hideGADBannerView];
        [UIView beginAnimations:@"animateAdBannerOn" context:NULL];
		// Assumes the banner view is just off the bottom of the screen.
        banner.frame = CGRectOffset(banner.frame, 0, -banner.frame.size.height);
        [UIView commitAnimations];
        self.bannerIsVisible = YES;
		
    }
}

- (void)hideGADBannerView
{
	if (self.isGADbannerVisible)
	{
		self.isGADbannerVisible = NO;
		[UIView beginAnimations:@"GADanimateAdBannerOff" context:NULL];
		// Assumes the banner view is placed at the bottom of the screen.
		self.gadBannerView.frame = CGRectMake(0, self.view.frame.size.height, self.view.frame.size.width, _gadBannerView.frame.size.height);
		[UIView commitAnimations];
	}
	
}

- (void)showGADBannerView
{
	if (!self.isGADbannerVisible)
	{
		self.isGADbannerVisible = YES;
		GADRequest *request = [GADRequest request];
		//request.testDevices = @[ GAD_SIMULATOR_ID ];
		[self.gadBannerView loadRequest:request];
		[UIView beginAnimations:@"GADanimateAdBannerOn" context:NULL];
		// Assumes the banner view is just off the bottom of the screen.
		self.gadBannerView.frame = CGRectMake(0, self.view.frame.size.height - _gadBannerView.frame.size.height, self.view.frame.size.width, _gadBannerView.frame.size.height);
		[UIView commitAnimations];
	}
}

- (void)bannerView:(ADBannerView *)banner didFailToReceiveAdWithError:(NSError *)error
{
	[self showGADBannerView];
	if (self.bannerIsVisible)
    {
        [UIView beginAnimations:@"animateAdBannerOff" context:NULL];
		// Assumes the banner view is placed at the bottom of the screen.
        banner.frame = CGRectOffset(banner.frame, 0, banner.frame.size.height);
        [UIView commitAnimations];
        self.bannerIsVisible = NO;
    }
}


- (void) adView: (GADBannerView*) view didFailToReceiveAdWithError: (GADRequestError*) error
{
	
}
- (void) adViewDidReceiveAd: (GADBannerView*) view
{
	
}

@end
