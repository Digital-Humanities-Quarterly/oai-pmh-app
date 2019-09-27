xquery version "3.1";

  module namespace oaisru="http://digitalhumanities.org/dhq/ns/oaipmh-source/sru";
(:  LIBRARIES  :)
  import module namespace rtrv="http://digitalhumanities.org/dhq/ns/oaipmh-source/retrieval"
    at "retrieval.xql";
(:  NAMESPACES  :)
  declare namespace http="http://expath.org/ns/http-client";
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
  
  (:~
    Construct a query in CQL to find all OAI-PMH records between two dates.
   :)
  declare function oaisru:make-time-range-query($from as xs:date?, $to as xs:date?) {
    let $useFrom :=
      if ( exists($from) ) then
        concat('oai.datestamp &gt;= ', $from)
      else ()
    let $useTo :=
      if ( exists($to) ) then
        concat('oai.datestamp &lt;= ', $to)
      else ()
    return 
      if ( empty($useFrom) and empty($useTo) ) then
        'oai.datestamp'
      else
        string-join(($useFrom, $useTo), ' and ')
  };
  
  (:~
    Given a namespace and query string, send a "searchRetrieve" request to the SRU service listed in the 
    configuration file. This request assumes that the list of records should begin at index position 1.
   :)
  declare function oaisru:search-retrieve($schema as xs:anyURI, $query as xs:string) {
    oaisru:search-retrieve($schema, $query, 1)
  };
  
  (:~
    Given a namespace, query string, and index position, send a "searchRetrieve" request to the SRU 
    service listed in the configuration file.
   :)
  declare function oaisru:search-retrieve($schema as xs:anyURI, $query as xs:string, $start-record as xs:integer) {
    (:if ( $schema = $oaisru:explain//zr:schema/@identifier/xs:anyURI(.) ) then:)
      let $params := map {
          'version': '1.1',
          'operation': 'searchRetrieve',
          'recordSchema': $schema,
          'query': $query,
          'startRecord': $start-record
        }
      return
(:        rtrv:make-url($oaisru:baseUrl, $params):)
        rtrv:get($oaisru:baseUrl, $params)
    (:else ():)
  };


(:  SUPPORT FUNCTIONS  :)
  
