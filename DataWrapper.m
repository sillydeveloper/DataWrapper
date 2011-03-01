//
//  DataWrapper.m
//
// Copyright (c) 2011, Andrew Ettinger
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification, are permitted provided 
// that the following conditions are met:
//
// Redistributions of source code must retain the above copyright notice, this list of conditions and the 
// following disclaimer. 
// Redistributions in binary form must reproduce the above copyright notice, this list of 
// conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
// The names of its contributors may not be used to endorse or promote products derived from this software without 
// specific prior written permission.
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, 
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE 
// GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF 
// LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY 
// OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "DataWrapper.h"
#import <objc/runtime.h>

@implementation DataWrapper

@synthesize key, table_name, fields;
NSString *db= @"your_database.sqlite";

-(void) load:(NSString *)byid
{	
	NSLog(@"finding %@", byid);
	self= [[self find:@"id" withValue:(NSString *)byid] objectAtIndex:0]; 
}

-(NSMutableArray*) find:(NSString*)field withValue:(NSString*)val
{
	NSLog(@"%@: finding %@ with value %@", self.table_name, field, val);
	return [self find:[NSString stringWithFormat:@"select * from %@ where %@='%@'",self.table_name,field,val]];
}

-(NSMutableArray*) find
{
	return [self find:[NSString stringWithFormat:@"select * from %@",self.table_name]];
}

-(NSMutableArray*) find:(NSString*)query
{
	NSLog(@"Running %@->find(%@)", self.table_name, query);
	
	NSMutableArray *results= [[NSMutableArray alloc] init];
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
														 NSUserDomainMask, YES);
	
	NSString *documentsPath = [paths objectAtIndex:0];
	NSString *filePath = [documentsPath stringByAppendingPathComponent: db];
	sqlite3 *database;
	
	if(!sqlite3_open([filePath UTF8String], &database) == SQLITE_OK) 
		NSLog(@"WARNING: failed to prepare statement with message '%s'.", sqlite3_errmsg(database));
	
	NSString *stmt= query;
	
	const char *sqlStatement = [stmt UTF8String];
	sqlite3_stmt *compiledStatement;
	
	if(!sqlite3_prepare_v2(database, sqlStatement, -1, &compiledStatement, NULL) == SQLITE_OK) 
		NSLog(@"WARNING: failed to prepare statement with message '%s'.", sqlite3_errmsg(database));
	
	while(sqlite3_step(compiledStatement) == SQLITE_ROW) 
	{	
		self= [[[self class] alloc] init]; 
		
		char *k;
		k= (char *)sqlite3_column_text(compiledStatement, 0);
		
		if (k != nil && strlen(k) > 0)
			self.key= [NSString stringWithUTF8String:k];
		else {
			NSLog(@"WARNING: NO KEY ON FIND");
		}
		
		for(int i=0; i < [self.fields count]; i++)
		{
			char *temp_char;
			SEL method;
			NSString *tmp;
			tmp= [self.fields objectAtIndex:i];
			method= NSSelectorFromString(tmp);
			
			temp_char = (char *)sqlite3_column_text(compiledStatement, i+1);
			
			if (temp_char != nil && strlen(temp_char) > 0)
			{
				[self setValue:[NSString stringWithUTF8String:temp_char] forKey:tmp];
			}
			else 
				[self setValue:@"" forKey:tmp];
		}
		[results addObject:self];
		[self release];
	}
	NSLog(@"Found %d record(s)", [results count]);
	sqlite3_finalize(compiledStatement);
	sqlite3_close(database);
	return results;
	
}


-(void) save
{
	if (!(self.fields && self.table_name))
		NSLog(@"WARNING: NSOBJECT WITHOUT TABLE AND DATA STRUCT!");
		
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
														 NSUserDomainMask, YES);

	NSString *documentsPath = [paths objectAtIndex:0];
	NSString *filePath = [documentsPath stringByAppendingPathComponent: db];

	sqlite3 *database;

	if(sqlite3_open([filePath UTF8String], &database) == SQLITE_OK) 
	{
		NSString *stmt;
		char *sqlStatement;
		if (self.key != nil)
		{	
			NSLog(@"Updating %@ record %@", self.table_name, self.key);
			stmt= [NSString stringWithFormat: @"update %@ set ", self.table_name];
			for (int i=0; i < [self.fields count]; i++) {
				stmt= [stmt stringByAppendingString: [self.fields objectAtIndex:i]];
				stmt= [stmt stringByAppendingString: @"=?"];
				if (i != [self.fields count] - 1)
					stmt= [stmt stringByAppendingString:@", "];
			}
			stmt= [stmt stringByAppendingString:@" where key=?"];
		}
		else
		{
			NSLog(@"Inserting new %@ record", self.table_name);
			stmt= [NSString stringWithFormat: @"insert into %@(", self.table_name];
			for (int i=0; i < [self.fields count]; i++) 
			{
				stmt= [stmt stringByAppendingString: [self.fields objectAtIndex:i]];
				if (i != [self.fields count] - 1)
					stmt= [stmt stringByAppendingString:@", "];
			}
			stmt= [stmt stringByAppendingString:@") values("];
			for (int i=0; i < [self.fields count]; i++) 
			{
				stmt= [stmt stringByAppendingString:@"?"];
				if (i != [self.fields count] - 1)
					stmt= [stmt stringByAppendingString:@", "];
			}
			stmt= [stmt stringByAppendingString:@")"];
		}
		NSLog(@"%@", stmt);
		sqlStatement= [stmt UTF8String];
		
		sqlite3_stmt *compiledStatement;
		
		if(!sqlite3_prepare_v2(database, sqlStatement, -1, &compiledStatement, NULL) == SQLITE_OK)
			NSLog(@"Error: failed to prepare statement with message '%s'.", sqlite3_errmsg(database));
		
		for (int i=0; i < [self.fields count]; i++) 
		{
			SEL method;
			NSString *tmp;
			tmp= [self.fields objectAtIndex:i];
			method= NSSelectorFromString(tmp);
			
			sqlite3_bind_text(compiledStatement, i+1,				  
						  [[self performSelector:method] UTF8String], -1,
						  SQLITE_TRANSIENT);
		}
		
		if (self.key != nil)
			sqlite3_bind_text(compiledStatement, [self.fields count]+1,
							  [self.key UTF8String], -1,
							  SQLITE_TRANSIENT);
		
		if(!sqlite3_step(compiledStatement) == SQLITE_DONE)
			NSLog(@"Error: failed to compile statement with message '%s'.", sqlite3_errmsg(database));
		
		sqlite3_finalize(compiledStatement);
		
		if (self.key == nil)
			self.key= [NSString stringWithFormat:@"%d", sqlite3_last_insert_rowid(database)];
	}

	sqlite3_close(database);	
}
@end
