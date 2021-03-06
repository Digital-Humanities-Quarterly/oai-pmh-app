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
  declare variable $oaixq:maximum-list-size := 
    $oaixq:configuration/*:ListX/*:resumptionToken/@maximumListSize/xs:integer(.);
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
              'resumptionToken': 'exclusive'
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
              'resumptionToken': 'exclusive'
            }
        },
      'ListSets': map {
          'handler': oaixq:list-sets#1,
          'parameters': map {
              'resumptionToken': 'exclusive'
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
    oaisru:list-identifiers('oai_dc', xs:date('2015-01-01'), (), 
      (), ())
  };



(:  GENERALIZED REQUEST FUNCTIONS  :)

  
  declare function oaixq:get-record($parameter-map as map(xs:string, item()?)) {
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
  
  declare function oaixq:identify($parameter-map as map(xs:string, item()?)) {
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
  
  declare function oaixq:list-identifiers($parameter-map as map(xs:string, item()?)) {
    let $resumptionToken := $parameter-map?('resumptionToken')
    let $from := $parameter-map?('from')
    let $until := $parameter-map?('until')
    let $metadataPrefix := $parameter-map?('metadataPrefix')
    let $set := $parameter-map?('set')
    let $recordSet := 
      oaixq:function-lookup('list-identifiers')($metadataPrefix, $from, $until, $set, $resumptionToken)
    return
      if ( $set and not(oaixq:supports-sets()) ) then
        oaixq:generate-oai-error('noSetHierarchy')
      else if ( empty($recordSet) ) then
        oaixq:generate-oai-error('noRecordsMatch')
      else (
          <ListIdentifiers>
            { $recordSet[not(self::resumptionToken)] }
          </ListIdentifiers>
          ,
          $recordSet[self::resumptionToken]
        )
  };
  
  declare function oaixq:list-metadata-formats($parameter-map as map(xs:string, item()?)) {
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
  
  declare function oaixq:list-records($parameter-map as map(xs:string, item()?)) {
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
  
  declare function oaixq:generate-base-resumption-token($parameter-map as map(xs:string, item()*)) {
    let $paramKeys := map:keys($parameter-map)[not(. = ('cursor', 'resumptionToken'))]
    let $paramStr :=
      for $key in $paramKeys
      let $value := $parameter-map?($key)
      return concat($key,'=',$value)
    return
      string-join($paramStr, '&amp;')
  };
  
  declare function oaixq:set-resumption-token($token-base as xs:string?, $record-index as xs:integer, 
     $total-size as xs:integer?) {
    let $cursor :=
      if ( $record-index ge 0 ) then
        attribute cursor { $record-index }
      else ()
    let $listSize :=
      if ( exists($total-size) and $total-size gt 0 ) then
        attribute completeListSize { $total-size }
      else ()
    let $token := 
      let $newCursor := xs:integer($record-index) + $oaixq:maximum-list-size + 1
      return concat('cursor=', xs:string($newCursor), $token-base)
    return
      <resumptionToken>{ $cursor, $listSize, text { $token } }</resumptionToken>
  };
  
  declare %private function oaixq:get-usable-date($date as xs:string*, $parameter-name as xs:string) {
    let $errorMsg :=
      concat('The parameter "',$parameter-name,'" must use the format "YYYY-MM-DD"')
    return
      if ( empty($date) ) then ()
      else if ( count($date) gt 1 ) then $date
      else if ( $date castable as xs:dateTime ) then
        if ( not(oaixq:supports-dateTime()) ) then
          <error code="badArgument">{$errorMsg}.</error>
        else $date cast as xs:dateTime
      else if ( $date castable as xs:date ) then
        $date cast as xs:date
      else
        <error code="badArgument">{$errorMsg}{ 
            if ( oaixq:supports-dateTime() ) then
              ' or "YYYY-MM-DDThh:mm:ssZ"'
            else ''
          }.</error>
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
        if ( oaixq:supports-dateTime() ) then
          'T[h01]:[m01]:[s01]Z'
        else ''
      return 
        concat('[Y0001]-[M01]-[D01]', $time)
    return
      format-dateTime($useDate, $picture)
  };
  
  (: Create an OAI-PMH query response wrapper around the verb-specific response. :)
  declare %private function oaixq:format-response($response as node()+, $verb as xs:string?, 
     $parameter-map as map(xs:string, item()*)?) {
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
            if ( exists($requestedValue) and $requestedValue castable as xs:string ) then
              attribute { $paramName } { $requestedValue cast as xs:string }
            else ()
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
        let $useFrom := oaixq:get-usable-date($from, 'from')
        let $useUntil := oaixq:get-usable-date($until, 'until')
        let $paramMap := map {
            'identifier':     $id,
            'metadataPrefix': $metadata-prefix,
            'from':           $useFrom,
            'until':          $useUntil,
            'set':            $set,
            'resumptionToken':$token
          }
        let $badArgumentErr := 
          oaixq:validate-arguments($paramMap, $verbDef?('parameters'))
        let $responseContent :=
          if ( exists($badArgumentErr) ) then $badArgumentErr
          else $handlerFn($paramMap)
        return
          oaixq:format-response($responseContent, $verb, $paramMap)
  };
  
  declare %private function oaixq:supports-sets() as xs:boolean {
    exists( $oaixq:configuration//*:ListSets/*:set )
  };
  
  declare %private function oaixq:supports-dateTime() as xs:boolean {
    $oaixq:configuration//*:granularity[1]/text() eq "YYYY-MM-DDThh:mm:ssZ"
  };
  
  (: An OAI-PMH request argument is only valid if: (1) all required parameters are present; (2) all 
    expected parameters have only one value (no doubled parameters); and (3) there aren't any unexpected 
    parameters. Unless, (4) an exclusive parameter value has been set, in which case no otherwise-valid 
    parameters can be present. :)
  declare %private function oaixq:validate-arguments($parameter-map as map(xs:string, item()*), 
     $expected-parameters as map(xs:string, xs:string*)?) as node()* {
    let $expectedKeys := 
      if ( not(empty($expected-parameters)) ) then
        map:keys($expected-parameters)
      else ()
    let $exclusiveArgs := 
      $expectedKeys[$expected-parameters?(.) eq 'exclusive']
    (: If this request includes an exclusive parameter, reduce $expectedKeys to the exclusive one. :)
    let $expectedKeys :=
      if ( exists($exclusiveArgs) and count($parameter-map?($exclusiveArgs)) eq 1 ) then
        $exclusiveArgs
      else $expectedKeys
    let $findErrorsInExpectedArgs :=
      for $paramName in $expectedKeys
      let $isRequired := $expected-parameters?($paramName) eq 'required'
      let $requestedValue := $parameter-map?($paramName)
      return
        if ( $isRequired and empty($requestedValue) ) then
          <error code="badArgument">Missing required parameter "{$paramName}".</error>
        else if ( count($requestedValue) gt 1 ) then
          <error code="badArgument">Only one value is allowed for parameter "{$paramName}".</error>
        else if ( $requestedValue instance of element(error) ) then
          $requestedValue
        else ()
    (: Make sure the other OAI-PMH parameters aren't present. 
        TODO: look for parameters in the request which were ignored by the RESTXQ interface. :)
    let $findUnexpectedArgs :=
      for $paramName in map:keys($parameter-map)[not(. = $expectedKeys)]
      let $requestedValue := $parameter-map?($paramName)
      return 
        if ( count($requestedValue) eq 0 ) then ()
        else if ( map:contains($expected-parameters, $paramName) and exists($exclusiveArgs) ) then
          <error code="badArgument">Parameter "{$paramName}" is not allowed when the resumption token 
            is set.</error>
        else
          <error code="badArgument">Parameter "{$paramName}" is not allowed for this verb.</error>
    return
      ( $findErrorsInExpectedArgs, $findUnexpectedArgs )
  };
