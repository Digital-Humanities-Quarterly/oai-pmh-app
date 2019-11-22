xquery version "3.1";

  module namespace oaixq="http://digitalhumanities.org/dhq/ns/oaipmh-repo";
(:  LIBRARIES  :)
  import module namespace oaisru="http://digitalhumanities.org/dhq/ns/oaipmh-source/sru"
    at "lib/source-sru.xql";
  import module namespace request="http://exquery.org/ns/request";
(:  NAMESPACES  :)
  declare default element namespace "http://www.openarchives.org/OAI/2.0/";
  declare namespace map="http://www.w3.org/2005/xpath-functions/map";
  declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
  declare namespace rest="http://exquery.org/ns/restxq";

(:~
  
  
  @author Ashley M. Clark, for Digital Humanities Quarterly
  2019
 :)


(:  VARIABLES  :)
  declare variable $oaixq:configuration := doc('CONFIG.xml')/*;
  declare variable $oaixq:request-types := 
    map {
      'GetRecord': map {
          'handler': oaixq:get-record#1,
          'parameters': map {
              'identifier': 'required',
              'metadataPrefix': 'required'
            }
        },
      'Identify': map {
          'handler': oaixq:identify#1,
          'parameters': ()
        },
      'ListIdentifiers': map {
          'handler': oaixq:list-identifiers#1,
          'parameters': map {
              'from': 'optional',
              'until': 'optional',
              'metadataPrefix': 'required',
              'set': 'optional',
              'resumptionToken': 'optional'
            }
        },
      'ListMetadataFormats': map {
          'handler': oaixq:list-metadata-formats#1,
          'parameters': map {
              'identifier': 'optional'
            }
        },
      'ListRecords': map {
          'handler': oaixq:list-records#1,
          'parameters': map {
              'from': 'optional',
              'until': 'optional',
              'metadataPrefix': 'required',
              'set': 'optional',
              'resumptionToken': 'optional'
            }
        },
      'ListSets': map {
          'handler': oaixq:list-sets#1,
          'parameters': map {
              'resumptionToken': 'optional'
            }
        }
    };
    
    declare variable $oaixq:source := $oaixq:configuration/@source/data(.);


(:  FUNCTIONS  :)
  
  declare
    %rest:GET
    %rest:path("/oai")
    %rest:query-param("verb", "{$verb}")
    %rest:query-param("identifier", "{$id}")
    %rest:query-param("metadataPrefix", "{$metadata-prefix}")
    %rest:query-param("from", "{$from}")
    %rest:query-param("until", "{$until}")
    %rest:query-param("set", "{$set}")
    %rest:query-param("resumptionToken", "{$token}")
    %output:method("xml")
    %output:media-type("text/xml")
    %output:omit-xml-declaration("no")
  function oaixq:respond-to-get-request($verb as xs:string*, $id as xs:string*, 
     $metadata-prefix as xs:string*, $from as xs:string*, $until as xs:string*, $set as xs:string*, 
     $token as xs:string*) {
    try { oaixq:route-request($verb, $id, $metadata-prefix, $from, $until, $set, $token) }
    catch * {
      <error>{ $err:code }</error>
    }
  };
  
  
  declare
    %rest:POST
    %rest:path("/oai")
    %rest:consumes("application/x-www-form-urlencoded")
    %rest:form-param("verb", "{$verb}")
    %rest:form-param("identifier", "{$id}")
    %rest:form-param("metadataPrefix", "{$metadata-prefix}")
    %rest:form-param("from", "{$from}")
    %rest:form-param("until", "{$until}")
    %rest:form-param("set", "{$set}")
    %rest:form-param("resumptionToken", "{$token}")
    %output:method("xml")
    %output:media-type("text/xml")
    %output:omit-xml-declaration("no")
  function oaixq:respond-to-post-request($verb as xs:string*, $id as xs:string*, 
     $metadata-prefix as xs:string*, $from as xs:string*, $until as xs:string*, $set as xs:string*, 
     $token as xs:string*) {
    try { oaixq:route-request($verb, $id, $metadata-prefix, $from, $until, $set, $token) }
    catch * {
      <error>{ $err:code }</error>
    }
  };
  
  
  declare
    %rest:GET
    %rest:path("/oai/test")
  function oaixq:testing() {
    oaisru:get-header('oai:digitalhumanities.org:dhq/000081')
  };



(:  GENERALIZED REQUEST FUNCTIONS  :)

  
  declare function oaixq:get-record($parameter-map as map(xs:string, xs:string*)) {
    let $recordId := $parameter-map?('identifier')
    let $metadataPrefix := $parameter-map?('metadataPrefix')
    let $header := oaixq:function-lookup('get-header')($recordId)
    let $record := oaixq:function-lookup('get-record')($recordId)
    return
      if ( not(exists($record)) ) then
        oaixq:generate-oai-error('idDoesNotExist') (: The metadata format may not be available either. :)
      else 
        <GetRecord>
          <record>
            { $header }
            <metadata>
              { $record }
            </metadata>
          </record>
        </GetRecord>
  };
  
  declare function oaixq:identify($parameter-map as map(xs:string, xs:string*)) {
    let $confIdentify := $oaixq:configuration//*:Identify
    let $oaiProtocol := <protocolVersion>2.0</protocolVersion>
    let $earliestDatestamp := <earliestDatestamp></earliestDatestamp>
    let $requestUri := <baseURL>{ request:uri() }</baseURL>
    return
      copy $useIdentify := $confIdentify
      modify
      (
        if ( not(exists($useIdentify/Q{}baseURL)) ) then
          insert node $requestUri after $useIdentify/*:repositoryName
        else (),
        insert node $oaiProtocol before ($useIdentify/*:adminEmail)[1],
        insert node $earliestDatestamp after ($useIdentify/*:adminEmail)[last()]
      )
      return $useIdentify
  };
  
  declare function oaixq:list-identifiers($parameter-map as map(xs:string, xs:string*)) {
    let $from := $parameter-map?('from')
    let $until := $parameter-map?('until')
    let $metadataPrefix := $parameter-map?('metadataPrefix')
    let $set := $parameter-map?('set')
    let $resumptionToken := $parameter-map?('resumptionToken')
    let $recordSet := 
      oaixq:function-lookup('list-identifiers')($metadataPrefix, $from, $until, $set, $resumptionToken)
    return
      if ( $set and not(oaixq:supports-sets()) ) then
        oaixq:generate-oai-error('noSetHierarchy')
      else if ( empty($recordSet) ) then
        oaixq:generate-oai-error('noRecordsMatch')
      else
        <ListIdentifiers>
          { $recordSet }
        </ListIdentifiers>
  };
  
  declare function oaixq:list-metadata-formats($parameter-map as map(xs:string, xs:string*)) {
    let $recordId := $parameter-map?('identifier')
    let $formats := oaixq:function-lookup('list-metadata-formats')($recordId)
    return
      (:if ( exists($recordId) and empty($formats) ) then
        oaixq:generate-oai-error('idDoesNotExist')
      else:) if ( exists($recordId) and empty($formats) ) then
        oaixq:generate-oai-error('noMetadataFormats')
      else
        <ListMetadataFormats>
          { $formats }
        </ListMetadataFormats>
  };
  
  declare function oaixq:list-records($parameter-map as map(xs:string, xs:string*)) {
    let $from := $parameter-map?('from')
    let $until := $parameter-map?('until')
    let $metadataPrefix := $parameter-map?('metadataPrefix')
    let $set := $parameter-map?('set')
    let $resumptionToken := $parameter-map?('resumptionToken')
    let $recordSet := 
      oaixq:function-lookup('list-records')($metadataPrefix, $from, $until, $set, $resumptionToken)
    return
      if ( $set and not(oaixq:supports-sets()) ) then
        oaixq:generate-oai-error('noSetHierarchy')
      else if ( empty($recordSet) ) then
        oaixq:generate-oai-error('noRecordsMatch')
      else
        <ListRecords>
          { $recordSet }
        </ListRecords>
  };
  
  declare function oaixq:list-sets($parameter-map as map(xs:string, xs:string*)) {
    let $resumptionToken := $parameter-map?('resumptionToken')
    return
      if ( not(oaixq:supports-sets()) ) then
        oaixq:generate-oai-error('noSetHierarchy')
      else
        (: TODO :)
        ()
  };



(:  SUPPORT FUNCTIONS  :)
  
  declare %private function oaixq:function-lookup($function-name as xs:string) {
    let $fn-map := map {
        'sru' : map {
          'get-header': oaisru:get-header#1,
          'get-record': oaisru:get-record#1,
          'list-identifiers': oaisru:list-identifiers#5,
          'list-metadata-formats': oaisru:list-metadata-formats#1,
          'list-records': oaisru:list-records#5
        }
      }
    return
      try {
        $fn-map?($oaixq:source)?($function-name)
      } catch * { () }
  };
  
  declare %private function oaixq:generate-oai-error($code as xs:string) {
    let $errorDescriptions := map {
        'badVerb': "Illegal OAI verb.",
        'cannotDisseminateFormat': "",
        'idDoesNotExist': "The given identifier is unknown or illegal in this repository.",
        'noRecordsMatch': "The current request matches no records.",
        'noMetadataFormats': "No metadata formats are available for the specified record.",
        'noSetHierarchy': "This OAI-PMH repository does not support sets."
      }
    return
      <error code="{$code}">{ $errorDescriptions?($code) }</error>
  };
  
  (: Translate the current xs:dateTime into the format described by the OAI-PMH standard and this
    repository's configuration file. :)
  declare %private function oaixq:get-utc-datestamp() {
    let $now := current-dateTime()
    return oaixq:get-utc-datestamp($now)
  };
  
  (: Translate a given xs:dateTime into the format described by the OAI-PMH standard and this 
    repository's configuration file. Datestamps must use Coordinated Universal Time. :)
  declare %private function oaixq:get-utc-datestamp($dateTime as xs:dateTime) {
    let $granularity := $oaixq:configuration//*:granularity/text()
    let $explicitTimezone := timezone-from-dateTime($dateTime)
    (: If $dateTime does not include an explicitly-set timezone, try to use the implicit timezone used 
      by the processor. :)
    let $timezone :=
      if ( exists($explicitTimezone) ) then
        $explicitTimezone
      else implicit-timezone()
    let $coordinatedUniversalTime := xs:dayTimeDuration('PT0S')
    (: Convert $dateTime to UTC as needed. :)
    let $useDate :=
      if ( $timezone eq $coordinatedUniversalTime ) then $dateTime
      else
        adjust-dateTime-to-timezone($dateTime, $coordinatedUniversalTime)
    (: Format the date to match the configured level of granularity. If the configuration is erroneous, 
      the full dateTime is used, rather than the date-only format. :)
    let $picture := 
      let $time :=
        if ( $granularity eq 'YYYY-MM-DD' ) then ''
        else 'T[h01]:[m01]:[s01]Z'
      return 
        concat('[Y0001]-[M01]-[D01]', $time)
    return
      format-dateTime($useDate, $picture)
  };
  
  (: Create an OAI-PMH query response wrapper around the verb-specific response. :)
  declare %private function oaixq:format-response($response as node()+, $verb as xs:string?, 
     $parameter-map as map(xs:string, xs:string*)?) {
    <OAI-PMH xmlns="http://www.openarchives.org/OAI/2.0/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xmlns:oai="http://www.openarchives.org/OAI/2.0/"
       xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/ http://www.openarchives.org/OAI/2.0/OAI-PMH.xsd">
      <responseDate>{ oaixq:get-utc-datestamp() }</responseDate>
      <request>{
        if ( $response[self::error[@code = ('badVerb', 'badArgument')]] ) then ()
        else (
          attribute verb { $verb },
          for $paramName in map:keys($parameter-map)
          let $requestedValue := $parameter-map?($paramName)
          return
            if ( empty($requestedValue) ) then ()
            else
              attribute { $paramName } { $requestedValue }
        )
        ,
        request:uri()
      }</request>
      { $response }
    </OAI-PMH>
  };
  
  (: Given the parts of an OAI-PMH request, generate a response. :)
  declare %private function oaixq:route-request($verb as xs:string*, $id as xs:string*, 
     $metadata-prefix as xs:string*, $from as xs:string*, $until as xs:string*, $set as xs:string*, 
     $token as xs:string*) {
    (: There must be one and only one OAI verb in the request, and that verb must be one of the six 
      defined in the OAI-PMH spec. :)
    let $badVerbErr := 
      if ( count($verb) ne 1 or not($verb = map:keys($oaixq:request-types)) ) then
        oaixq:generate-oai-error('badVerb')
      else ()
    return
      if ( exists($badVerbErr) ) then
        oaixq:format-response($badVerbErr, (), ())
      else
        let $verbDef := $oaixq:request-types?($verb)
        let $handlerFn := $verbDef?('handler')
        let $paramMap := map {
            'identifier':     $id,
            'metadataPrefix': $metadata-prefix,
            'from':           $from,
            'until':          $until,
            'set':            $set,
            'resumptionToken':$token
          }
        let $badArgumentErr := oaixq:validate-arguments($paramMap, $verbDef?('parameters'))
        let $responseContent :=
          if ( exists($badArgumentErr) ) then $badArgumentErr
          else $handlerFn($paramMap)
        return
          oaixq:format-response($responseContent, $verb, $paramMap)
  };
  
  declare %private function oaixq:supports-sets() as xs:boolean {
    exists( $oaixq:configuration//*:ListSets/*:set )
  };
  
  (: An OAI-PMH request argument is only valid if (1) all required parameters are present; (2) all 
    expected parameters have only one value (no doubled parameters); and (3) there aren't any unexpected 
    parameters. :)
  declare %private function oaixq:validate-arguments($parameter-map as map(xs:string, xs:string*), 
     $expected-parameters as map(xs:string, xs:string*)?) as node()* {
    let $expectedKeys := 
      if ( not(empty($expected-parameters)) ) then
        map:keys($expected-parameters)
      else ()
    let $findErrorsInExpectedArgs :=
      for $paramName in $expectedKeys
      let $isRequired := $expected-parameters?($paramName) eq 'required'
      let $requestedValue := $parameter-map?($paramName)
      return
        if ( $isRequired and empty($requestedValue) ) then
          <error code="badArgument">Missing required parameter "{$paramName}".</error>
        else if ( count($requestedValue) gt 1 ) then
          <error code="badArgument">Only one value is allowed for parameter "{$paramName}".</error>
        else ()
    (: Make sure the other OAI-PMH parameters aren't present. 
        TODO: look for parameters in the request which were ignored by the RESTXQ interface. :)
    let $findUnexpectedArgs :=
      for $paramName in map:keys($parameter-map)[not(. = $expectedKeys)]
      let $requestedValue := $parameter-map?($paramName)
      return 
        if ( count($requestedValue) eq 0 ) then () 
        else
          <error code="badArgument">Parameter "{$paramName}" is not allowed for this verb.</error>
    return
      ( $findErrorsInExpectedArgs, $findUnexpectedArgs )
  };
