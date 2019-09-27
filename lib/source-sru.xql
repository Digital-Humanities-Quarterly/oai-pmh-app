xquery version "3.1";

  module namespace oaisru="http://digitalhumanities.org/dhq/ns/oaipmh-source/sru";
(:  LIBRARIES  :)
  import module namespace http="http://expath.org/ns/http-client";
  import module namespace rtrv="http://digitalhumanities.org/dhq/ns/oaipmh-source/retrieval"
    at "retrieval.xql";
(:  NAMESPACES  :)
  declare namespace map="http://www.w3.org/2005/xpath-functions/map";
  declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
  declare namespace rest="http://exquery.org/ns/restxq";
  declare namespace sru="http://www.loc.gov/zing/srw/";
  declare namespace zr="http://explain.z3950.org/dtd/2.1/";

(:~
  Query and retrieve metadata records from an SRU (Search/Retrieve via URL) repository.
  
  @author Ashley M. Clark, for Digital Humanities Quarterly
  2019
 :)
 
(:  VARIABLES  :)
  declare variable $oaisru:config := doc('../CONFIG.xml')//SRU;
  declare variable $oaisru:baseUrl := $oaisru:config/baseURL/normalize-space(.);
  declare variable $oaisru:explain := rtrv:get($oaisru:baseUrl);

(:  FUNCTIONS  :)
  
  declare function oaisru:searchRetrieve($schema as xs:anyURI, $query as xs:string) {
    oaisru:searchRetrieve($schema, $query, 1)
  };
  
  declare function oaisru:searchRetrieve($schema as xs:anyURI, $query as xs:string, $start-record as xs:integer) {
    (:if ( $schema = $oaisru:explain//zr:schema/@identifier/xs:anyURI(.) ) then:)
      let $params := map {
          'operation': 'searchRetrieve',
          'recordSchema': $schema,
          'query': $query,
          'startRecord': $start-record
        }
      return
        rtrv:get($oaisru:baseUrl, $params)
    (:else ():)
  };


(:  SUPPORT FUNCTIONS  :)
  
