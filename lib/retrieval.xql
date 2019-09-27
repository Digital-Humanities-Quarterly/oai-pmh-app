xquery version "3.1";

  module namespace rtrv="http://digitalhumanities.org/dhq/ns/oaipmh-source/retrieval";
(:  LIBRARIES  :)
(:  NAMESPACES  :)
  declare namespace http="http://expath.org/ns/http-client";
  declare namespace map="http://www.w3.org/2005/xpath-functions/map";
  declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

(:~
  Convenience functions for sending requests with the EXPath HTTP Client module.
  
  @author Ashley M. Clark, for Digital Humanities Quarterly
  2019
 :)
 
(:  VARIABLES  :)
  

(:  FUNCTIONS  :)
  
  declare function rtrv:get($base-url as xs:string) {
    rtrv:get($base-url, map {})
  };
  
  declare function rtrv:get($base-url as xs:string, $parameter-map as map(xs:string, item()*)) {
    let $url := rtrv:make-url($base-url, $parameter-map)
    let $request :=
      <http:request method="GET" href="{$url}" follow-redirect="true"/>
    let $response :=
      http:send-request($request)
    let $statusCode := $response[1]/@status/data(.)
    return
      switch ($statusCode)
        case '200' return $response[2]
        default return $response[1]
  };
  
  declare function rtrv:make-url($base-url as xs:string, $parameter-map as map(xs:string, item()*)) {
    let $params :=
      map:for-each($parameter-map, function($key, $val) {
          concat($key,'=',$val)
        })
    let $params := string-join($params, '&amp;')
    return
      iri-to-uri(concat($base-url,'?',$params))
  };


(:  SUPPORT FUNCTIONS  :)
