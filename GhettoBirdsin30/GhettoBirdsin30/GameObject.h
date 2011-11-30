//
//  GameObject.h
//  GhettoBirdsin30
//
//  Created by Chris Hill on 11/29/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Box2D.h"
#import "cocos2d.h"

@interface GameObject : NSObject
enum ObjectTypes
{
	ghettoHero,
	ghettoEnemy,
	ghettoDestructable
};	


-(id)initWithFrameName:(NSString*)frameName strength:(NSInteger)objStrength type:(ObjectTypes)objType position:(CGPoint)objPos;

@property (nonatomic,retain) CCSprite* sprite;
@property (nonatomic, assign) CGFloat strength;
@property (nonatomic, assign) NSInteger type;
@property (nonatomic, assign) b2Body* body;


@end
