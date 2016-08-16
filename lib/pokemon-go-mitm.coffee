###
  Pokemon Go (c) MITM node proxy
  by Michael Strassburger <codepoet@cpan.org>
###

Proxy = require 'http-mitm-proxy'
POGOProtos = require 'pokemongo-protobuf'
changeCase = require 'change-case'
http = require 'http'
https = require 'https'
fs = require 'fs'
_ = require 'lodash'
request = require 'request'
rp = require 'request-promise'
Promise = require 'bluebird'
DNS = require 'dns'
zlib = require 'zlib'
getRawBody = require 'raw-body'

class PokemonGoMITM
  ports:
    proxy: 8081
    endpoint: 8082

  endpoint:
    api: 'pgorelease.nianticlabs.com'
    oauth: 'android.clients.google.com'
    ptc: 'sso.pokemon.com'
    storage: 'storage.googleapis.com'

  endpointIPs: {}

  clientSignature: '321187995bc7cdc2b5fc91b11a96e2baa8602c62'

  responseEnvelope: 'POGOProtos.Networking.Envelopes.ResponseEnvelope'
  requestEnvelope: 'POGOProtos.Networking.Envelopes.RequestEnvelope'

  requestHandlers: {}
  responseHandlers: {}
  requestEnvelopeHandlers: []
  responseEnvelopeHandlers: []

  requestInjectQueue: []
  lastRequest: null
  lastCtx: null

  proxy: null
  server: null

  constructor: (options) ->
    @ports.proxy = options.port or 8081
    @ports.endpoint = options.endpoint or 8082

    @debug = options.debug or false

    console.log "[+++] PokemonGo MITM [++++]"

    @resolveEndpoints()
    .then => @setupProxy()
    .then => @setupEndpoint()

  close: ->
    console.log "[+] Stopping MITM Proxy..."
    @proxy.close()
    @server.close()

  resolveEndpoints: ->
    Promise
    .mapSeries (host for name, host of @endpoint), (endpoint) =>
      new Promise (resolve, reject) =>
        @log "[+] Resolving #{endpoint}"
        DNS.resolve endpoint, "A", (err, addresses) =>
          return reject err if err
          @endpointIPs[ip] = endpoint for ip in addresses
          resolve()
    .then =>
      @log "[+] Resolving done", @endpointIPs


  setupProxy: ->
    @proxy = new Proxy()
      .use Proxy.gunzip
      .onConnect @handleProxyConnect
      .onRequest @handleProxyRequest
      .onError @handleProxyError
      .listen port: @ports.proxy, =>
        console.log "[+] Proxy listening on #{@ports.proxy}"
        console.log "[!] -> PROXY USAGE: make sure to have .http-mitm-proxy/certs/ca.pem installed on your device"

    @proxy.silent = true

  setupEndpoint: ->
    requestedActions = []
    @server = http.createServer (req, res) =>
      getRawBody req
      .then (buffer) =>
        @handleEndpointConnect req, res, buffer

    @server.listen @ports.endpoint, =>
      console.log "[+] Virtual endpoint listening on #{@ports.endpoint}"
      console.log "[!] -> ENDPOINT USAGE: configure 'custom endpoint' in pokemon-go-xposed"

  handleEndpointConnect: (req, res, buffer) ->
    @log "[+] Handling request to virtual endpoint"
    [buffer, requestedActions] = @handleRequest buffer

    delete req.headers.host
    delete req.headers["content-length"]
    req.headers.connection = "Close"

    rp
      url: "https://#{@endpoint.api}#{req.url}"
      method: "POST"
      body: buffer
      encoding: null
      headers: req.headers
      resolveWithFullResponse: true

    .then (response) =>
      @log "[+] Forwarding result from real endpoint"

      zlib.gunzip response.body, (err, decoded) =>
        buffer = @handleResponse decoded, requestedActions

        zlib.gzip buffer, (err, encoded) =>
          response.headers["content-length"] = buffer.length if buffer
          res.writeHead response.statusCode, response.headers
          res.end encoded, "binary"

    .catch (e) =>
      console.log "[-] #{e}"

  handleProxyConnect: (req, socket, head, callback) =>
    return callback() unless req.url.match /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}:443/
    ip = req.url.split(/:/)[0]

    # Overwrite the request URL if the IP matches on of our intercepted hosts
    req.url = @endpointIPs[ip]+':443' if @endpointIPs[ip]

    callback()

  handleProxyRequest: (ctx, callback) =>
    switch ctx.clientToProxyRequest.headers.host
      # Intercept all calls to the API
      when @endpoint.api then @proxyRequestHandler ctx

      # Intercept calls to the oAuth endpoint to patch the signature
      when @endpoint.oauth then @proxySignatureHandler ctx
    
    callback()

  proxyRequestHandler: (ctx) ->
    @log "[+++] Request to #{ctx.clientToProxyRequest.url}"

    ### Client Reuqest Handling ###
    requestedActions = []
    requestChunks = []

    ctx.onRequestData (ctx, chunk, callback) =>
      requestChunks.push chunk
      callback null, null

    ctx.onRequestEnd (ctx, callback) =>
      [buffer, requestedActions] = @handleRequest Buffer.concat requestChunks

      ctx.proxyToServerRequest.write buffer

      @log "[+] Waiting for response..."
      callback()

    ### Server Response Handling ###
    responseChunks = []
    ctx.onResponseData (ctx, chunk, callback) =>
      responseChunks.push chunk
      callback()

    ctx.onResponseEnd (ctx, callback) =>
      buffer = @handleResponse Buffer.concat(responseChunks), requestedActions

      ctx.proxyToClientResponse.end buffer
      callback false

  handleRequest: (buffer) ->
    try
      data = POGOProtos.parseWithUnknown buffer, @requestEnvelope
    catch e
      @log "[-] Parsing protobuf of RequestEnvelope failed.."
      return [buffer]

    requested = []
    @lastRequest = data

    originalData = _.cloneDeep data

    for handler in @requestEnvelopeHandlers
      data = handler(data) or data

    for id,request of data.requests
      protoId = changeCase.pascalCase request.request_type
    
      # Queue the ProtoId for the response handling
      requested.push "POGOProtos.Networking.Responses.#{protoId}Response"
      
      proto = "POGOProtos.Networking.Requests.Messages.#{protoId}Message"
      unless proto in POGOProtos.info()
        @log "[-] Request handler for #{protoId} isn't implemented yet.."
        continue

      try
        decoded = if request.request_message
          POGOProtos.parseWithUnknown request.request_message, proto
        else {}
      catch e
        @log "[-] Parsing protobuf of #{protoId} failed.."
        continue
      
      originalRequest = _.cloneDeep decoded
      afterHandlers = @handleRequestAction protoId, decoded

      # disabled since signature validation
      # unless _.isEqual originalRequest, afterHandlers
      #   @log "[!] Overwriting "+protoId
      #   request.request_message = POGOProtos.serialize afterHandlers, proto

    # disabled since signature validation
    # for request in @requestInjectQueue
    #   unless data.requests.length < 5
    #     @log "[-] Delaying inject of #{request.action} because RequestEnvelope is full"
    #     break

    #   @log "[+] Injecting request to #{request.action}"
    #   injected++

    #   requested.push "POGOProtos.Networking.Responses.#{request.action}Response"
    #   data.requests.push
    #     request_type: changeCase.constantCase request.action
    #     request_message: POGOProtos.serialize request.data, "POGOProtos.Networking.Requests.Messages.#{request.action}Message"

    # @requestInjectQueue = @requestInjectQueue.slice injected

    # unless _.isEqual originalData, data
    #   @log "[+] Recoding RequestEnvelope"
    #   buffer = POGOProtos.serialize data, @requestEnvelope

    [buffer, requested]

  handleResponse: (buffer, requested) ->
    try
      data = POGOProtos.parseWithUnknown buffer, @responseEnvelope
    catch e
      @log "[-] Parsing protobuf of ResponseEnvelope failed: #{e}"
      return buffer

    originalData = _.cloneDeep data

    for handler in @responseEnvelopeHandlers
      data = handler(data, {}) or data

    for id,response of data.returns
      proto = requested[id]
      if proto in POGOProtos.info()
        decoded = POGOProtos.parseWithUnknown response, proto
        
        protoId = proto.split(/\./).pop().split(/Response/)[0]

        originalResponse = _.cloneDeep decoded
        afterHandlers = @handleResponseAction protoId, decoded
        unless _.isEqual afterHandlers, originalResponse
          @log "[!] Overwriting "+protoId
          data.returns[id] = POGOProtos.serialize afterHandlers, proto

        # disabled since signature validation
        # if injected and data.returns.length-injected-1 >= id
        #   # Remove a previously injected request to not confuse the client
        #   @log "[!] Removing #{protoId} from response as it was previously injected"
        #   delete data.returns[id]

      else
        @log "[-] Response handler for #{requested[id]} isn't implemented yet.."

    # Overwrite the response in case a hook hit the fan
    unless _.isEqual originalData, data
      buffer = POGOProtos.serialize data, @responseEnvelope

    buffer


  proxySignatureHandler: (ctx) ->
    requestChunks = []

    ctx.onRequestData (ctx, chunk, callback) =>
      requestChunks.push chunk
      callback null, null

    ctx.onRequestEnd (ctx, callback) =>
      buffer = Buffer.concat requestChunks
      if /Email.*com.nianticlabs.pokemongo/.test buffer.toString()
        buffer = new Buffer buffer.toString().replace /&client_sig=[^&]*&/, "&client_sig=#{@clientSignature}&"

      ctx.proxyToServerRequest.write buffer
      callback()

  handleProxyError: (ctx, err, errorKind) =>
    url = if ctx and ctx.clientToProxyRequest then ctx.clientToProxyRequest.url else ''
    @log '[-] ' + errorKind + ' on ' + url + ':', err

  handleRequestAction: (action, data) ->
    @log "[+] Request for action #{action}: "
    @log data if data

    handlers = [].concat @requestHandlers[action] or [], @requestHandlers['*'] or []
    for handler in handlers
      data = handler(data, action) or data

    data

  handleResponseAction: (action, data) ->
    @log "[+] Response for action #{action}"
    @log data if data

    handlers = [].concat @responseHandlers[action] or [], @responseHandlers['*'] or []
    for handler in handlers
      data = handler(data, action) or data

    data

  # disabled since signature validation
  # injectRequest: (action, data) ->
  #   unless "POGOProtos.Networking.Requests.Messages.#{action}Message" in POGOProtos.info()
  #     @log "[-] Can't inject request #{action} - proto not implemented"
  #     return

  #   @requestInjectQueue.push
  #     action: action
  #     data: data

  # craftRequest: (action, data, requestEnvelope=@lastRequest, url=undefined) ->
  #   @log "[+] Crafting request for #{action}"

  #   requestEnvelope.request_id ?= 1000000000000000000-Math.floor(Math.random()*1000000000000000000)

  #   requestEnvelope.requests = [
  #     request_type: changeCase.constantCase action
  #     request_message: POGOProtos.serialize data, "POGOProtos.Networking.Requests.Messages.#{changeCase.pascalCase action}Message"
  #   ]

  #   _.defaults requestEnvelope, @lastRequest

  #   buffer = POGOProtos.serialize requestEnvelope, @requestEnvelope
  #   url ?= 'https://' + @lastCtx.clientToProxyRequest.headers.host + '/' + @lastCtx.clientToProxyRequest.url

  #   return rp(
  #     url: url
  #     method: 'POST'
  #     body: buffer
  #     encoding: null
  #     headers:
  #       'Content-Type': 'application/x-www-form-urlencoded'
  #       'Content-Length': Buffer.byteLength buffer
  #       'Connection': 'Close'
  #       'User-Agent': @lastCtx?.clientToProxyRequest?.headers['user-agent']
  #     ).then((buffer) =>
  #       try
  #         @log "[+] Response for crafted #{action}"
          
  #         decoded = POGOProtos.parseWithUnknown buffer, @responseEnvelope
  #         data = POGOProtos.parseWithUnknown decoded.returns[0], "POGOProtos.Networking.Responses.#{changeCase.pascalCase action}Response"
          
  #         @log data
  #         data
  #       catch e
  #         @log "[-] Parsing of response to crafted #{action} failed: #{e}"
  #         throw e
  #     ).catch (e) =>
  #       @log "[-] Crafting a request failed with #{e}"
  #       throw e

  setResponseHandler: (action, cb) ->
    @addResponseHandler action, cb
    this

  addResponseHandler: (action, cb) ->
    @responseHandlers[action] ?= []
    @responseHandlers[action].push(cb)
    this

  setRequestHandler: (action, cb) ->
    @addRequestHandler action, cb
    this

  addRequestHandler: (action, cb) ->
    @requestHandlers[action] ?= []
    @requestHandlers[action].push(cb)
    this

  addRequestEnvelopeHandler: (cb, name=undefined) ->
    @requestEnvelopeHandlers.push cb
    this

  addResponseEnvelopeHandler: (cb, name=undefined) ->
    @responseEnvelopeHandlers.push cb
    this

  log: (text) ->
    console.log text if @debug

module.exports = PokemonGoMITM
