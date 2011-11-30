//
//  HelloWorldLayer.mm
//  GhettoBirdsin30
//
//  Created by Chris Hill on 11/29/11.
//  Copyright __MyCompanyName__ 2011. All rights reserved.
//


// Import the interfaces
#import "HelloWorldLayer.h"
#import "GameObject.h"

//Pixel to metres ratio. Box2D uses metres as the unit for measurement.
//This ratio defines how many pixels correspond to 1 Box2D "metre"
//Box2D is optimized for objects of 1x1 metre therefore it makes sense
//to define the ratio so that your most common object type is 1x1 metre.
#define PTM_RATIO 50

#define DAMPING 1.0f

class GhettoContactListener : public b2ContactListener
{
    public:
	void BeginContact(b2Contact* contact)
	{
	}
	
	void EndContact(b2Contact* contact)
	{
	}

	void PreSolve(b2Contact* contact, const b2Manifold* oldManifold)
	{
		b2WorldManifold worldManifold;
		contact->GetWorldManifold(&worldManifold);
		b2PointState state1[2], state2[2];
		b2GetPointStates(state1, state2, oldManifold, contact->GetManifold());
		if (state2[0] == b2_addState)
		{
			const b2Body* bodyA = contact->GetFixtureA()->GetBody();
			const b2Body* bodyB = contact->GetFixtureB()->GetBody();
			b2Vec2 point = worldManifold.points[0];
			b2Vec2 vA = bodyA->GetLinearVelocityFromWorldPoint(point);
			b2Vec2 vB = bodyB->GetLinearVelocityFromWorldPoint(point);
			float32 approachVelocity = abs(b2Dot(vB - vA, worldManifold.normal));
			float32 threshold = 1.0f;
			if (approachVelocity > threshold)
			{
				GameObject* objectA = (GameObject*)bodyA->GetUserData();
				GameObject* objectB = (GameObject*)bodyB->GetUserData();
				if(objectA == nil || objectB == nil){
					return;
				}
				objectA.strength -= approachVelocity;
				objectB.strength -= approachVelocity;
			}
		}
	}
	void PostSolve(b2Contact* contact)
	{
	}
};

// enums that will be used as tags
enum {
	kTagTileMap = 1,
	kTagBatchNode = 1,
	kTagAnimation1 = 1,
};


@interface HelloWorldLayer()

@property (nonatomic,retain) GameObject* hero;
@property (nonatomic,retain) NSMutableArray* gameObjects;
@property (nonatomic, assign) BOOL isDragging;
@property (nonatomic,retain) CCNode* feedbackContainer;
@property (nonatomic,retain) NSMutableArray* feedback;

- (void) addSpriteSheets;
- (void)addBackground;
- (void) addHero;
- (void) addEnemyAt:(CGPoint)point;
- (void) addEnemies;
-(void)addDestructable:(NSString*)frameName withStrength:(NSInteger)strength at:(CGPoint)point;
- (void) addDestructables;
- (void) addBoundingBox:(CGRect)rect;
- (void) addBoundingBoxes;
-(void)addPhysicsToDestructable:(GameObject*)gameObject;
- (void) addPhysicsToUnit:(GameObject*) gameObject;
-(BOOL)isTouching:(GameObject*)gameObject atPoint:(CGPoint)point;
- (void) addPullbackFeedback;
-(void)updatePullbackFeedback:(CGPoint)point;
- (void) applyForceToHero:(CGPoint)touchPos;
-(void)removeGameObject:(GameObject*)gameObject;
-(void) addPoofEffectAt:(CGPoint)point;

@end

// HelloWorldLayer implementation
@implementation HelloWorldLayer
@synthesize hero,gameObjects, isDragging, feedback, feedbackContainer;

+(CCScene *) scene
{
	// 'scene' is an autorelease object.
	CCScene *scene = [CCScene node];
	
	// 'layer' is an autorelease object.
	HelloWorldLayer *layer = [HelloWorldLayer node];
	
	// add layer as a child to scene
	[scene addChild: layer];
	
	// return the scene
	return scene;
}

// on "init" you need to initialize your instance
-(id) init
{
	// always call "super" init
	// Apple recommends to re-assign "self" with the "super" return value
	if( (self=[super init])) {
		
		// enable touches
		self.isTouchEnabled = YES;
		
		// enable accelerometer
		self.isAccelerometerEnabled = YES;
		
		CGSize screenSize = [CCDirector sharedDirector].winSize;
		CCLOG(@"Screen width %0.2f screen height %0.2f",screenSize.width,screenSize.height);
		
		// Define the gravity vector.
		b2Vec2 gravity;
		gravity.Set(0.0f, -10.0f);
		
		// Do we want to let bodies sleep?
		// This will speed up the physics simulation
		bool doSleep = true;
		
		// Construct a world object, which will hold and simulate the rigid bodies.
		world = new b2World(gravity, doSleep);
		
		world->SetContactListener(new GhettoContactListener);
		
		world->SetContinuousPhysics(true);
		
		// Debug Draw functions
		m_debugDraw = new GLESDebugDraw( PTM_RATIO );
		world->SetDebugDraw(m_debugDraw);
		
		uint32 flags = 0;
		flags += b2DebugDraw::e_shapeBit;
//		flags += b2DebugDraw::e_jointBit;
//		flags += b2DebugDraw::e_aabbBit;
//		flags += b2DebugDraw::e_pairBit;
//		flags += b2DebugDraw::e_centerOfMassBit;
		m_debugDraw->SetFlags(flags);		
		
		self.gameObjects = [NSMutableArray arrayWithCapacity:5];
		[self addSpriteSheets];
		[self addBackground];
		[self addPullbackFeedback];
		[self addHero];
		[self addEnemies];
		[self addDestructables];
		[self addBoundingBoxes];

		[self schedule: @selector(tick:)];
	}
	return self;
}

-(void) draw
{
	// Default GL states: GL_TEXTURE_2D, GL_VERTEX_ARRAY, GL_COLOR_ARRAY, GL_TEXTURE_COORD_ARRAY
	// Needed states:  GL_VERTEX_ARRAY, 
	// Unneeded states: GL_TEXTURE_2D, GL_COLOR_ARRAY, GL_TEXTURE_COORD_ARRAY
	glDisable(GL_TEXTURE_2D);
	glDisableClientState(GL_COLOR_ARRAY);
	glDisableClientState(GL_TEXTURE_COORD_ARRAY);
	
	world->DrawDebugData();
	
	// restore default GL states
	glEnable(GL_TEXTURE_2D);
	glEnableClientState(GL_COLOR_ARRAY);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);

}



-(void) tick: (ccTime) dt
{
	//It is recommended that a fixed time step is used with Box2D for stability
	//of the simulation, however, we are using a variable time step here.
	//You need to make an informed choice, the following URL is useful
	//http://gafferongames.com/game-physics/fix-your-timestep/
	
	int32 velocityIterations = 8;
	int32 positionIterations = 1;
	
	// Instruct the world to perform a single step of simulation. It is
	// generally best to keep the time step and iterations fixed.
	world->Step(dt, velocityIterations, positionIterations);

	BOOL worldAsleep = true;

	//Iterate over the bodies in the physics world
	for (b2Body* b = world->GetBodyList(); b; b = b->GetNext())
	{
		if (b->GetUserData() != NULL) {
			//Synchronize the AtlasSprites position and rotation with the corresponding body
			GameObject* gameObject = (GameObject*)b->GetUserData();
			CCSprite* myActor = gameObject.sprite;
			myActor.position = CGPointMake( b->GetPosition().x * PTM_RATIO, b->GetPosition().y * PTM_RATIO);
			myActor.rotation = -1 * CC_RADIANS_TO_DEGREES(b->GetAngle());
		}	
		if(worldAsleep && b->IsAwake()){
			b2Vec2 v = b->GetLinearVelocity();
			float32 a = b->GetAngularVelocity();
			if(v.x < b2_linearSleepTolerance && v.y < b2_linearSleepTolerance && a < b2_angularSleepTolerance){
				if(b->GetUserData() != nil){
					worldAsleep = false;
				}
			}else{
				worldAsleep = false;
			}
		}
	}
	
	
	//Iterate over gameObjects and destroy anything that has been damaged.
	for(int i=0;i<self.gameObjects.count;i++){
		GameObject* gameObject = [self.gameObjects objectAtIndex:i];
		if(gameObject.strength <= 0){
			[self removeGameObject:gameObject];
			i--;
		}
	}
	
	if(worldAsleep && self.hero == nil){
			[self addHero];
	}
	
	if(self.hero.body && !self.hero.body->IsAwake()){
		[self removeGameObject:self.hero];
	}

}


- (void) addSpriteSheets 
{
	[[CCSpriteFrameCache sharedSpriteFrameCache] addSpriteFramesWithFile:@"assets/sprites1.plist"];
	[[CCSpriteFrameCache sharedSpriteFrameCache] addSpriteFramesWithFile:@"assets/poof.plist"];
}

- (void) addBackground 
{
	CCSprite* background = [CCSprite spriteWithSpriteFrameName:@"ghetto_bg.png"];
	background.position = CGPointMake(512,384);
	[self addChild:background];

}                                   

- (void) addHero 
{
	self.hero = [[[GameObject alloc] 
			initWithFrameName:@"ghetto_bird.png" 
			strength:100000 
			type:ghettoHero 
			position:CGPointMake(235,195)] 
			autorelease];
			
	[self addChild:self.hero.sprite];
}

- (void) addEnemyAt:(CGPoint)point
{
	GameObject* enemy = [[[GameObject alloc] 
			initWithFrameName:@"ghetto_pig.png" 
			strength:5 
			type:ghettoEnemy
			position:point] 
			autorelease];
	[self.gameObjects addObject:enemy];
	[self addChild:enemy.sprite];
	[self addPhysicsToUnit:enemy];
}

- (void) addEnemies
{
	[self addEnemyAt:CGPointMake(728,128)];
	[self addEnemyAt:CGPointMake(872,128)];
	[self addEnemyAt:CGPointMake(797,250)];

}


- (void)addDestructable:(NSString*)frameName withStrength:(NSInteger)strength at:(CGPoint)point
{
	GameObject* destructable = [[[GameObject alloc] 
		initWithFrameName:frameName 
		strength:strength 
		type:ghettoDestructable 
		position:point] 
		autorelease];
	[self addChild:destructable.sprite];
	[self.gameObjects addObject:destructable];
	[self addPhysicsToDestructable:destructable];

}

- (void) addDestructables 
{
	CGFloat maltStrength = 5;
	CGFloat woodStrength = 10;
	[self addDestructable:@"malt_40.png" withStrength:maltStrength at:CGPointMake(640,144)];
	[self addDestructable:@"malt_40.png" withStrength:maltStrength at:CGPointMake(793,144)];
	[self addDestructable:@"malt_40.png" withStrength:maltStrength at:CGPointMake(948,144)];
	
	[self addDestructable:@"wood.png" withStrength:woodStrength at:CGPointMake(715,206)];
	[self addDestructable:@"wood.png" withStrength:woodStrength at:CGPointMake(873,206)];
	
	[self addDestructable:@"malt_40.png" withStrength:maltStrength at:CGPointMake(723,271)];
	[self addDestructable:@"malt_40.png" withStrength:maltStrength at:CGPointMake(870,271)];
	
	[self addDestructable:@"wood.png" withStrength:woodStrength at:CGPointMake(795,335)];
}

- (void) addBoundingBox:(CGRect)rect
{
	// Define the dynamic body.
	b2BodyDef bodyDef;
	CGPoint p = rect.origin;
	CGSize s = rect.size;

	bodyDef.position.Set(p.x/PTM_RATIO, p.y/PTM_RATIO);
	bodyDef.allowSleep = true;
	bodyDef.linearDamping = DAMPING;
	bodyDef.angularDamping = DAMPING;
	b2Body *body = world->CreateBody(&bodyDef);
	
	// Define another box shape for our dynamic body.
	b2PolygonShape box;
	box.SetAsBox((s.width/2) / PTM_RATIO, (s.height/2) / PTM_RATIO );//These are mid points for our 1m box
	
	// Define the dynamic body fixture.
	b2FixtureDef fixtureDef;
	fixtureDef.shape = &box;	
	fixtureDef.density = 1.0f;
	fixtureDef.friction = 1.0f;
	fixtureDef.restitution = 0.5;
	body->CreateFixture(&fixtureDef);
	
}


- (void) addBoundingBoxes 
{
		// bottom
	[self addBoundingBox:CGRectMake(512, 50, 1024, 100)];
	
	// top
	[self addBoundingBox:CGRectMake(512, 808, 1024, 100)];
	
	// left
	[self addBoundingBox:CGRectMake(-40, 384, 100, 768)];
	
	// right
	[self addBoundingBox:CGRectMake(1064, 384, 100, 768)];
	
}

-(void)addPhysicsToDestructable:(GameObject*)gameObject
{
		// Define the dynamic body.
	b2BodyDef bodyDef;
	bodyDef.type = b2_dynamicBody;
	CGPoint p = gameObject.sprite.position;
	CGSize s = gameObject.sprite.contentSize;

	bodyDef.position.Set(p.x/PTM_RATIO, p.y/PTM_RATIO);
	bodyDef.userData = gameObject;
	bodyDef.allowSleep = true;
	bodyDef.linearDamping = DAMPING;
	bodyDef.angularDamping = DAMPING;
	b2Body *body = world->CreateBody(&bodyDef);
	gameObject.body = body;
	
	// Define another box shape for our dynamic body.
	b2PolygonShape dynamicBox;
	dynamicBox.SetAsBox((s.width/2) / PTM_RATIO, (s.height/2) / PTM_RATIO );//These are mid points for our 1m box
	
	// Define the dynamic body fixture.
	b2FixtureDef fixtureDef;
	fixtureDef.shape = &dynamicBox;	
	fixtureDef.density = 1.0f;
	fixtureDef.friction = 0.8f;
	body->CreateFixture(&fixtureDef);
	
}

- (void) addPhysicsToUnit:(GameObject*) gameObject
{
	// Define the dynamic body.
	b2BodyDef bodyDef;
	bodyDef.type = b2_dynamicBody;
	CGPoint p = gameObject.sprite.position;
	CGSize s = gameObject.sprite.contentSize;

	bodyDef.position.Set(p.x/PTM_RATIO, p.y/PTM_RATIO);
	bodyDef.userData = gameObject;
	bodyDef.allowSleep = true;
	bodyDef.linearDamping = DAMPING;
	bodyDef.angularDamping = DAMPING;
	b2Body *body = world->CreateBody(&bodyDef);
	gameObject.body = body;
	
	// Define another box shape for our dynamic body.
	b2CircleShape dynamicCircle;
	dynamicCircle.m_radius = (s.height/2) / PTM_RATIO;//These are mid points for our 1m box
	
	// Define the dynamic body fixture.
	b2FixtureDef fixtureDef;
	fixtureDef.shape = &dynamicCircle;	
	fixtureDef.density = 1.0f;
	fixtureDef.friction = 1.0f;
	body->CreateFixture(&fixtureDef);
}


- (void)ccTouchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
{
	for( UITouch *touch in touches ) {
		CGPoint location = [touch locationInView: [touch view]];
		
		location = [[CCDirector sharedDirector] convertToGL: location];
		if([self isTouching:self.hero atPoint:location]){
			NSLog(@"[CH] Touched hero...");
			self.isDragging = true;
			[self updatePullbackFeedback:location];
		}
	}
}

- (void)ccTouchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	//Add a new body/atlas sprite at the touched location
	for( UITouch *touch in touches ) {
		CGPoint location = [touch locationInView: [touch view]];
		location = [[CCDirector sharedDirector] convertToGL: location];
		if(self.isDragging){
			[self updatePullbackFeedback:location];
		}
	}
}

- (void)ccTouchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	//Add a new body/atlas sprite at the touched location
	for( UITouch *touch in touches ) {
		CGPoint location = [touch locationInView: [touch view]];
		location = [[CCDirector sharedDirector] convertToGL: location];
		if([self isTouching:self.hero atPoint:location]){
			NSLog(@"[CH] canceling drag");
		}else{
			if(self.isDragging){
				NSLog(@"[CH] sending this bad boy flying");
				[self applyForceToHero:location];
			}
		}
		self.feedbackContainer.visible = false;
		self.isDragging = false;
	}
}

-(BOOL)isTouching:(GameObject*)gameObject atPoint:(CGPoint)point
{
	CGPoint gPos = gameObject.sprite.position;
	CGSize gSize = gameObject.sprite.contentSize;
	
	CGRect hitArea = CGRectMake(gPos.x - gSize.width/2, gPos.y - gSize.height/2, gSize.width, gSize.height);
	if(CGRectContainsPoint(hitArea, point)){
		return YES;
	}
	return NO;
}



- (void) addPullbackFeedback 
{
	self.feedback = [NSMutableArray arrayWithCapacity:5];
	self.feedbackContainer = [CCNode node];
	self.feedbackContainer.visible = false;
	[self addChild:self.feedbackContainer];
	for(int i=0;i<5; i++){
		CCSprite* dot = [CCSprite spriteWithSpriteFrameName:@"dot.png"];
		[self.feedbackContainer addChild:dot];
		[self.feedback addObject:dot];
	}
}

-(void)updatePullbackFeedback:(CGPoint)point
{
		if([self isTouching:self.hero atPoint:point]){
		self.feedbackContainer.visible = false;
	}else{
		self.feedbackContainer.visible = true;
		// [CH] Draw the dots within the container in a line between the hero and the touch point
		CGFloat magnitude = 0.0;
		CGPoint heroPos = self.hero.sprite.position;
		// [CH] Get the (negative) slope of the line.
		CGPoint slope = CGPointMake(point.x - heroPos.x, point.y - heroPos.y);
		CGFloat increment = 1.0 / self.feedback.count;
		for(CCSprite* sprite in self.feedback){
			CGPoint p = CGPointMake((magnitude * slope.x) + heroPos.x, (magnitude * slope.y)  + heroPos.y);
			sprite.position = p;
			magnitude += increment;
		}
	}
}

- (void) applyForceToHero:(CGPoint)touchPos
{
	[self addPhysicsToUnit:self.hero];
	[self.gameObjects addObject:self.hero];

	CGFloat forceModifier = 15.0;
	CGPoint heroPos = self.hero.sprite.position;
	b2Vec2 force = b2Vec2(-(touchPos.x - heroPos.x) * forceModifier, -(touchPos.y - heroPos.y)  * forceModifier);
	
	self.hero.body->ApplyForce(force, self.hero.body->GetPosition());
}

-(void)removeGameObject:(GameObject*)gameObject
{
	[self addPoofEffectAt:gameObject.sprite.position];
	[gameObject.sprite removeFromParentAndCleanup:YES];
	[self.gameObjects removeObject:gameObject];
	
	world->DestroyBody(gameObject.body);
	
	if(self.hero == gameObject){
		self.hero = nil;
	}

}


-(void) addPoofEffectAt:(CGPoint)point
{
	CCSprite* poof = [CCSprite spriteWithSpriteFrameName:@"poof1.png"];
	[self addChild:poof];
	poof.position = point;
	
	NSArray* poofNames = [NSArray arrayWithObjects:@"poof1.png", @"poof2.png", @"poof3.png", @"poof4.png", @"poof5.png", nil];
	NSMutableArray* frames = [NSMutableArray arrayWithCapacity:5];
	for(NSString* frameName in poofNames){
		[frames addObject: [[CCSpriteFrameCache sharedSpriteFrameCache] spriteFrameByName:frameName]];
	}
	CCAnimation* animation = [CCAnimation animationWithFrames:frames delay:0.06];
	CCAnimate* animateAction = [CCAnimate actionWithAnimation:animation restoreOriginalFrame:NO];
	CCCallFuncN* removeAction = [CCCallFuncN actionWithTarget:self selector:@selector(removeNode:)];
	CCSequence* sequence = [CCSequence actions:animateAction, removeAction, nil];
	[poof runAction:sequence];
}

-(void)removeNode:(CCNode*)node
{
	[node removeFromParentAndCleanup:YES];
}

// on "dealloc" you need to release all your retained objects
- (void) dealloc
{
	// in case you have something to dealloc, do it in this method
	delete world;
	world = NULL;
	
	delete m_debugDraw;

	// don't forget to call "super dealloc"
	[super dealloc];
}
@end
