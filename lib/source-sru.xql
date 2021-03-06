xquery version "3.1";

  module namespace oaisru="http://digitalhumanities.org/dhq/ns/oaipmh-source/sru";
(:  LIBRARIES  :)
  import module namespace rtrv="http://digitalhumanities.org/dhq/ns/oaipmh-source/retrieval"
    at "retrieval.xql";
  import module namespace oaixq="http://digitalhumanities.org/dhq/ns/oaipmh-repo"
    at "../oaipmh.xq";
(:  NAMESPACES  :)
  declare namespace array="http://www.w3.org/2005/xpath-functions/array";
  declare namespace http="http://expath.org/ns/http-client";
  declare namespace map="http://www.w3.org/2005/xpath-functions/map";
  declare namespace oai="http://www.openarchives.org/OAI/2.0/";
  declare namespace oaidc="http://www.openarchives.org/OAI/2.0/oai_dc/";
  declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
  declare namespace rest="http://exquery.org/ns/restxq";
  declare namespace sru="http://www.loc.gov/zing/srw/";
  declare namespace zr="http://explain.z3950.org/dtd/2.0/";
  
  declare copy-namespaces no-preserve, inherit;

(:~
  Query and retrieve metadata records from an SRU (Search/Retrieve via URL) repository.
  
  @author Ashley M. Clark, for Digital Humanities Quarterly
  2019
 :)
 
(:  VARIABLES  :)
  declare variable $oaisru:config := doc('../CONFIG.xml')//SRU;
  declare variable $oaisru:base-url := $oaisru:config/baseURL/normalize-space(.);
  declare variable $oaisru:explain := rtrv:get($oaisru:base-url);
  
  declare variable $oaisru:schema-oaidc := 
    xs:anyURI('http://www.openarchives.org/OAI/2.0/oai_dc/');
  declare variable $oaisru:schema-oaiheader :=
    xs:anyURI('http://www.openarchives.org/OAI/2.0/');
  declare variable $oaisru:all-namespaces :=
    $oaisru:explain//zr:schemaInfo/zr:schema/@identifier/data(.);
  
  declare variable $oaisru:schema-tmpheader :=
    xs:anyURI('http://www.openarchives.org/OAI/2.0/%23header');


(:  FUNCTIONS  :)
  
  declare function oaisru:get-header($identifier as xs:string) {
    let $query := oaisru:query-by-id($identifier)
    let $sruResponse := oaisru:search-retrieve($oaisru:schema-oaiheader, $query)
    let $header := $sruResponse//oai:header
    return oaisru:clean-oai-header($header)
  };
  
  declare function oaisru:get-record($identifier as xs:string) {
    let $query := oaisru:query-by-id($identifier)
    let $sruResponse := oaisru:search-retrieve($oaisru:schema-oaidc, $query)
    return $sruResponse//oaidc:dc
  };
  
  declare function oaisru:list-identifiers($metadata-prefix as xs:string, $from as item()?, 
     $to as item()?, $set as item()?, $resumption-token as item()?) {
    let $query := oaisru:query-by-date-range($from, $to)
    let $sruResults :=
      oaisru:manage-results($oaisru:schema-tmpheader, $query, 1)
    let $records := 
      for $header in $sruResults
      return oaisru:clean-oai-header($header)
    return $records
  };
  
  declare function oaisru:list-metadata-formats($identifier as xs:string?) as node()* {
    let $schemas := 
      $oaisru:explain//zr:schemaInfo/zr:schema[@identifier ne xs:string($oaisru:schema-oaiheader)]
    let $useSchemas := 
      if ( exists($identifier) ) then
        for $ns in $oaisru:all-namespaces
        let $query := oaisru:query-by-id($identifier)
        let $record := oaisru:search-retrieve(xs:anyURI($ns), $query)
        return
          if ( exists($record) ) then 
            $schemas[@identifier eq $ns]
          else ()
      else $schemas
    return
      for $schema in $useSchemas
      return
        <metadataFormat xmlns="http://www.openarchives.org/OAI/2.0/">
          <metadataPrefix>{ $schema/@name/data(.) }</metadataPrefix>
          <schema>{ $schema/@location/data(.) }</schema>
          <metadataNamespace>{ $schema/@identifier/data(.) }</metadataNamespace>
        </metadataFormat>
  };
  
  declare function oaisru:list-records($metadata-prefix as xs:string, $from as item()?, 
     $to as item()?, $set as item()?, $resumption-token as item()?) {
    let $query := oaisru:query-by-date-range($from, $to)
    let $schema := oaisru:dereference-prefix($metadata-prefix)
    let $tmpNs := xs:anyURI(concat(xs:string($oaisru:schema-oaiheader), '%23header'))
    let $headers := oaisru:manage-results($tmpNs, $query, 1)
    let $records :=
      if ( exists($schema) ) then
        oaisru:manage-results($schema, $query, 1)
      else ()
    return (: TODO: this assumes that the header will be in sync with the record, but this may not be the case! :)
      for $index in 1 to count($records)
      let $header := $headers[$index]
      let $record := $records[$index]
      return
        <record xmlns="http://www.openarchives.org/OAI/2.0/">
          { oaisru:clean-oai-header($header) }
          <metadata>
            { $record }
          </metadata>
        </record>
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
  declare function oaisru:search-retrieve($schema as xs:anyURI, $query as xs:string, 
     $start-record as xs:integer?) {
    if ( xs:string($schema) = ($oaisru:all-namespaces, $oaisru:schema-tmpheader) ) then
      let $params := map {
          'version': '1.1',
          'operation': 'searchRetrieve',
          'recordSchema': $schema,
          'query': $query,
          'startRecord': $start-record
        }
      return
        rtrv:get($oaisru:base-url, $params)
    else ()
  };


(:  SUPPORT FUNCTIONS  :)
  
  (:~
    Get rid of the "oai" prefix, since the OAI-PMH wrapper isn't using it. Also get rid of the SRU 
    namespace. Manipulating the plain text serialization is not an elegant (XML-aware) way to accomplish 
    these tasks, but it's fast and easy to implement.
   :)
  declare %private function oaisru:clean-oai-header($header as item()) {
    let $serialized :=
      serialize($header, map {'indent': 'no', 'method': 'xml'})
    let $replacePrefixes := 
      replace($serialized, '(</?)oai:', '$1')
      => replace('xmlns:oai=', 'xmlns=')
      => replace('\s+xmlns:srw="http://www\.loc\.gov/zing/srw/"', '')
    return
      parse-xml($replacePrefixes)
  };
  
  (:~
    Given a prefix for a metadata standard, retrieve the schema namespace with which it is associated.
   :)
  declare function oaisru:dereference-prefix($metadata-prefix as xs:string) as xs:anyURI? {
    $oaisru:explain//zr:schemaInfo/zr:schema[@name eq $metadata-prefix]/@identifier/xs:anyURI(.)
  };
  
  (:~
    Retrieve metadata records through recursive calls to an SRU repository. The configured maximum list 
    size (see CONFIG.xml) is used as an upper bound.
   :)
  declare function oaisru:manage-results($schema as xs:anyURI, $query as xs:string, 
     $start-record as xs:integer) {
    oaisru:manage-results($schema, $query, $start-record, $oaixq:maximum-list-size)
  };
  
  (:~
    Make a retrieval request of an SRU repository, and test the response against the target number of 
    records.
   :)
  declare %private function oaisru:manage-results($schema as xs:anyURI, $query as xs:string, 
     $start-record as xs:integer, $target as xs:integer) {
    let $sruMax := 
      $oaisru:explain//zr:setting[@type eq 'maximumRecords']/normalize-space(.)
    let $req1 := oaisru:search-retrieve($schema, $query, $start-record)
    let $records := $req1//sru:recordData/*
    let $nextRecord :=
      $req1/sru:searchRetrieveResponse/sru:nextRecordPosition/xs:integer(.)
    let $totalRecords := 
      $req1/sru:searchRetrieveResponse/sru:numberOfRecords/xs:integer(.)
    let $resToken :=
      oaixq:set-resumption-token((), $start-record - 1, $totalRecords)
    return
      if ( count($records) gt $target ) then
        ( subsequence($records, 1, $target), $resToken )
      else if ( exists($nextRecord) and count($records) lt $target ) then
        let $revisedTarget := $target - count($records)
        let $addtlRecords := 
          oaisru:manage-results($schema, $query, $nextRecord, $revisedTarget)
        return
          ( $records, $addtlRecords, $resToken )
      else $records
  };
  
  (:~
    Construct a query in CQL to find all OAI-PMH records between two dates.
   :)
  declare %private function oaisru:query-by-date-range($from as item()?, $to as item()?) {
    let $useFrom :=
      if ( $from castable as xs:date ) then
        concat('oai.datestamp&gt;="', $from,'"')
      else ()
    let $useTo :=
      if ( $to castable as xs:date ) then
        concat('oai.datestamp&lt;="', $from,'"')
      else ()
    return 
      if ( empty($useFrom) and empty($useTo) ) then
        'oai.datestamp=all'
      else
        string-join(($useFrom, $useTo), '%20and%20')
  };
  
  (:~
    Construct a query in CQL to find an OAI-PMH record with a given identifier.
   :)
  declare %private function oaisru:query-by-id($identifier as xs:string) {
    concat('oai.identifier exact "',$identifier,'"')
  };
