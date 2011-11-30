//
//  GameObject.m
//  GhettoBirdsin30
//
//  Created by Chris Hill on 11/29/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "GameObject.h"

@implementation GameObject
@synthesize sprite, strength, type, body;

-(id)initWithFrameName:(NSString*)frameName strength:(NSInteger)objStrength type:(ObjectTypes)objType position:(CGPoint)objPos
{
	self = [super init];
	if(self){
		self.sprite = [CCSprite spriteWithSpriteFrameName:frameName];
		self.sprite.position = objPos;
		self.strength = objStrength;
		self.type = objType;
	}
	return self;
}

-(void)dealloc
{
	[sprite release];
	[super dealloc];
}
@end
