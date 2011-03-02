Concept
-------

A simple way to find XML elements inside NSData using XPath and libxml2.

Specifically built for use with complex XML like soap result sets using multiple namespaces.

Usage
-----
    
    NSData* responseData; // assume this exists from http result
    
    NSString* query = @"//sp:List/@Title";
    
    NSDictionary* namespaces = [NSDictionary dictionaryWithObjectsAndKeys:
      @"http://schemas.xmlsoap.org/soap/envelope/", @"soap",
      @"http://www.w3.org/2001/XMLSchema-instance", @"xsi",
      @"http://www.w3.org/2001/XMLSchema", @"xsd",
      @"http://schemas.microsoft.com/sharepoint/soap/", @"sp",
    nil];
    
    NSArray* results = [responseData findXPath:query usingNamespaces:namespaces];
    
    STAssertNotNil(results, @"results should not be nil");  
    STAssertEquals((int)results.count, (int)1, [NSString stringWithFormat:@"found %d", [results count]]);
    
    XPathResult* r = [results objectAtIndex:0];
    
    STAssertNotNil(r, @"first object in array should not be nil");
    STAssertEqualObjects(r.name, @"Title", @"name should be what we searched for")
    STAssertEqualObjects(r.content, @"Calendar", @"attr value not as expected");
    

Sometimes it's better to use your own block instead of the default one that builds an NSArray
(this is more of a functional programming / jQuery approach)
    
    __block int blockExecCount = 0;
    
    [responseData findXPath:@"//sp:List" usingNamespaces:namespaces executeBlock:^(XPathResult* r) {
        STAssertNotNil(r, @"result should not be nil");
        
        STAssertEqualObjects(r.name, @"List", @"name of element matched not list");
        STAssertEqualObjects(r.content, @"", @"content of list should be empty");
        
        ++blockExecCount;
    }];
    
    STAssertTrue(blockExecCount != 0, @"why no blocks executed?");

LICENSE
-------

http://www.opensource.org/licenses/mit-license.php
