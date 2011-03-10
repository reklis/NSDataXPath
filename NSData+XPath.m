//
//  NSData+XPath.m
//  

#import "NSData+XPath.h"

@implementation XPathResult

@synthesize xpath;
@synthesize name;
@synthesize content;
@synthesize attributes;

@end


// adapted from http://www.xmlsoft.org/examples/xpath1.c
// don't forget to include $(SDKROOT)/usr/include/libxml2 in the search header path

#import <libxml/tree.h>
#import <libxml/parser.h>
#import <libxml/xpath.h>
#import <libxml/xpathInternals.h>

#define nsxmlstr( _S_ ) [NSString stringWithCString:(const char *) _S_ encoding:NSUTF8StringEncoding]

id NSStringMake(xmlChar* x) {
    NSString* s = nsxmlstr(x);
    xmlFree(x);
    return s;
}

@implementation NSData(XPath)

- (void) findXPath:(NSString*)query usingNamespaces:(NSDictionary*)namespaces executeBlock:(XPathResultBlock)block
{
    xmlDocPtr doc = xmlReadMemory([self bytes], [self length], "", NULL, XML_PARSE_RECOVER);
	
    if (doc == NULL)
	{
		NSLog(@"Unable to parse null doc.");
		return;
    }
    
    xmlXPathContextPtr xpathCtx = xmlXPathNewContext(doc);
    if(xpathCtx == NULL) {
        NSLog(@"Error: unable to create new XPath context");
        
        // no context, free doc and bail
        xmlFreeDoc(doc); 
        return;
    }
    
    for (NSString* k in [namespaces allKeys]) {
        NSString* v = [namespaces objectForKey:k];
        
        xmlChar* prefix = (xmlChar *)[k cStringUsingEncoding:NSUTF8StringEncoding];
        xmlChar* href = (xmlChar *)[v cStringUsingEncoding:NSUTF8StringEncoding];
        int regerr = xmlXPathRegisterNs(xpathCtx, prefix, href);
        if (regerr != 0) {
            NSLog(@"Error: unable to register NS with prefix=\"%@\" and href=\"%@\"\n", prefix, href);
            
            // registration failed, free context and doc then bail
            xmlXPathFreeContext(xpathCtx); 
            xmlFreeDoc(doc);
            return;
        }
    }
    
    xmlChar* xpathExpr = (xmlChar *)[query cStringUsingEncoding:NSUTF8StringEncoding];
    xmlXPathObjectPtr xpathObj = xmlXPathEvalExpression(xpathExpr, xpathCtx);
    if(xpathObj == NULL) {
        NSLog(@"Error: unable to evaluate xpath expression \"%s\"\n", xpathExpr);
        
        // no xpath object, free context and doc, then bail
        xmlXPathFreeContext(xpathCtx); 
        xmlFreeDoc(doc); 
        return;
    }
    
    xmlNodeSetPtr nodes = xpathObj->nodesetval;
    
    // debug
    //FILE* f = fopen("/xpath.log", "w");
    
    int size = (nodes) ? nodes->nodeNr : 0;
    NSLog(@"%@ Matched (%d) Nodes", query, size);
    
    for (int i = 0; i < size; ++i) {
        xmlNodePtr currentNode = nodes->nodeTab[i];
        
        //xmlElemDump(f, doc, currentNode);
        
        XPathResult* r = [[[XPathResult alloc] init] autorelease];
        
        NSString* nodeName = nsxmlstr(currentNode->name);
        r.name = nodeName;
        [nodeName release];
        
        NSString* xpath = NSStringMake(xmlGetNodePath(currentNode));
        r.xpath = xpath;
        [xpath release];
        
        NSString* content = NSStringMake(xmlNodeGetContent(currentNode));
        r.content = content;
        [content release];
        
        xmlAttrPtr attribute = currentNode->properties;
        if (attribute) {
            NSMutableDictionary* nodeAttributeDictionary = [NSMutableDictionary dictionary];
            while (attribute) {
                NSString* v = NSStringMake(xmlGetProp(currentNode, attribute->name));
                
                NSString* k = nsxmlstr(attribute->name);
                [nodeAttributeDictionary setObject:v forKey:k];
                
                [v release];
                [k release];
                
                attribute = attribute->next;
            }
            r.attributes = nodeAttributeDictionary;
        }
        
        block(r);
    }
    
    //fclose(f);
    
    // success, free xpath object, context and doc
    xmlXPathFreeObject(xpathObj);
    xmlXPathFreeContext(xpathCtx); 
    xmlFreeDoc(doc);
}

- (NSArray*) findXPath:(NSString*)query usingNamespaces:(NSDictionary *)namespaces
{
    if (!query) return nil;
    
    __block NSMutableArray* matches = [NSMutableArray array];
    
    [self findXPath:query
    usingNamespaces:namespaces
       executeBlock:^(XPathResult* r) {
           [matches addObject:r];
       }
    ];
    
    return matches;
}

- (NSString*) contentAtXPath:(NSString*)query usingNamespaces:(NSDictionary *)namespaces
{
    if (!query) return nil;
    
    NSArray* a = [self findXPath:query usingNamespaces:namespaces];
    if ([a count] > 0) {
        return [((XPathResult*) [a objectAtIndex:0]) content];
    } else {
        return nil;
    }
}

@end
