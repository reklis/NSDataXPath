//
//  NSData+XPath.m
//  

#import "NSData+XPath.h"

@implementation XPathResult

@synthesize xpathQuery;
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

/**
 * print_xpath_nodes:
 * @nodes:		the nodes set.
 * @output:		the output file handle.
 *
 * Prints the @nodes content to @output.
 */
/*void
print_xpath_nodes(xmlNodeSetPtr nodes, FILE* output) {
    xmlNodePtr cur;
    int size;
    int i;
    
    assert(output);
    size = (nodes) ? nodes->nodeNr : 0;
    
    fprintf(output, "Result (%d nodes):\n", size);
    for(i = 0; i < size; ++i) {
        assert(nodes->nodeTab[i]);
        
        if(nodes->nodeTab[i]->type == XML_NAMESPACE_DECL) {
            xmlNsPtr ns;
            
            ns = (xmlNsPtr)nodes->nodeTab[i];
            cur = (xmlNodePtr)ns->next;
            if(cur->ns) { 
                fprintf(output, "= namespace \"%s\"=\"%s\" for node %s:%s\n", 
                ns->prefix, ns->href, cur->ns->href, cur->name);
            } else {
                fprintf(output, "= namespace \"%s\"=\"%s\" for node %s\n", 
                ns->prefix, ns->href, cur->name);
            }
        } else if(nodes->nodeTab[i]->type == XML_ELEMENT_NODE) {
            cur = nodes->nodeTab[i];   	    
            if(cur->ns) { 
                    fprintf(output, "= element node \"%s:%s\"\n", 
                cur->ns->href, cur->name);
            } else {
                    fprintf(output, "= element node \"%s\"\n", 
                cur->name);
            }
        } else {
            cur = nodes->nodeTab[i];    
            fprintf(output, "= node \"%s\": type %d\n", cur->name, cur->type);
        }
    }
}*/

#define nsxmlstr( S ) [NSString stringWithCString:(const char *) S encoding:NSUTF8StringEncoding]


@implementation NSData(XPath)

- (void) findXPath:(NSString*)query usingNamespaces:(NSDictionary*)namespaces executeBlock:(XPathResultBlock)block
{
    // TODO: move init and cleanup somewhere else
    xmlInitParser();
    
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
    NSLog(@"Nodes Matched: %d", size);
    
    for (int i = 0; i < size; ++i) {
        xmlNodePtr currentNode = nodes->nodeTab[i];
        
        //xmlElemDump(f, doc, currentNode);
        
        XPathResult* r = [[[XPathResult alloc] init] autorelease];
        r.xpathQuery = query;
        r.name = nsxmlstr(currentNode->name);
        r.content = nsxmlstr(xmlNodeGetContent(currentNode));
        
        xmlAttrPtr attribute = currentNode->properties;
        if (attribute) {
            NSMutableDictionary* nodeAttributeDictionary = [NSMutableDictionary dictionary];
            while (attribute) {
                NSString* k = nsxmlstr(attribute->name);
                NSString* v = nsxmlstr(xmlGetProp(currentNode, attribute->name));
                [nodeAttributeDictionary setValue:v forKey:k];
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
    
    xmlCleanupParser();
}

- (NSArray*) findXPath:(NSString *)query usingNamespaces:(NSDictionary *)namespaces
{
    __block NSMutableArray* matches = [NSMutableArray array];
    
    [self findXPath:query
    usingNamespaces:namespaces
       executeBlock:^(XPathResult* r) {
           [matches addObject:r];
       }
    ];
    
    return matches;
}


@end
