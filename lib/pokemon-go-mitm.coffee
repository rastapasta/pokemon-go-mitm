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
forge = require 'node-forge'
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

  class Session
    id: null
    url: null
    expiration: 0
    lastRequest: null
    requestInjectQueue: []
    data: {}

    constructor: (id, url) ->
      @id = id
      @url = url

    setRequest: (req, url) ->
      @lastRequest = req
      @url = url
      if req.auth_ticket
        @expiration = parseInt req.auth_ticket.expire_timestamp_ms
        Buffer.concat([req.auth_ticket.start, req.auth_ticket.end]).toString()
      else if req.auth_info
        req.auth_info.token.contents

    setResponse: (res) ->
      if res.auth_ticket
        @expiration = parseInt res.auth_ticket.expire_timestamp_ms
        Buffer.concat([res.auth_ticket.start, res.auth_ticket.end]).toString()

  sessions: {}

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
        console.log "[!] -> PROXY USAGE: install http://<host>:#{@ports.endpoint}/ca.crt as a trusted certificate"

    @proxy.silent = true

  setupEndpoint: ->
    @server = http.createServer (req, res) =>
      @handleEndpointRequest req, res

    @server.listen @ports.endpoint, =>
      console.log "[+] Virtual endpoint listening on #{@ports.endpoint}"
      console.log "[!] -> ENDPOINT USAGE: configure 'custom endpoint' in pokemon-go-xposed"

  handleEndpointRequest: (req, res) ->
    @log "[+++] #{req.method} request for #{req.url}"
    switch req.url
      when '/ca.pem', '/ca.crt', '/ca.der'
        return @endpointCertHandler req, res

    getRawBody req
    .then (buffer) =>
      @handleEndpointConnect req, res, buffer

  handleEndpointConnect: (req, res, buffer) ->
    @log "[+] Handling request to virtual endpoint"
    [buffer, session] = @handleRequest buffer, req.url

    delete req.headers.host
    delete req.headers["content-length"]
    req.headers.connection = "Close"

    rp
      url: "https://#{@endpoint.api}#{req.url}"
      method: req.method
      body: buffer
      encoding: null
      headers: req.headers
      resolveWithFullResponse: true

    .then (response) =>
      @log "[+] Forwarding result from real endpoint"

      send = (buffer) ->
        response.headers["content-length"] = buffer.length if buffer

        res.writeHead response.statusCode, response.headers
        res.end buffer, "binary"

      unless response.headers["content-encoding"] is "gzip"
        send @handleResponse response.body, session

      else
        zlib.gunzip response.body, (err, decoded) =>
          buffer = @handleResponse decoded, session
          zlib.gzip buffer, (err, encoded) =>
            send encoded

    .catch (e) =>
      console.log "[-] #{e}"

  endpointCertHandler: (req, res) ->
    path = @proxy.sslCaDir + '/certs' + req.url
    if toDer = /\.(crt|der)$/.test path
      path = path.replace /\.(crt|der)$/, '.pem'

    fs.readFile path, (err, data) ->
      code = 200
      type = "application/x-pem-file"

      if err
        code = 404
        type = "text/html"
        data = "<html>\n<title>404</title>\n<body>Not found</body>\n</html>"
      else if toDer
        type = "application/x-x509-ca-cert"
        data = forge.pem.decode(data)[0].body;

      res.writeHead code, {"Content-Type": type, "Content-Length": data.length}
      res.end data, 'binary'

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
    requestChunks = []
    session = null

    ctx.onRequestData (ctx, chunk, callback) =>
      requestChunks.push chunk
      callback null, null

    ctx.onRequestEnd (ctx, callback) =>
      [buffer, session] = @handleRequest Buffer.concat(requestChunks), ctx.clientToProxyRequest.url

      ctx.proxyToServerRequest.write buffer

      @log "[+] Waiting for response..."
      callback()

    ### Server Response Handling ###
    responseChunks = []
    ctx.onResponseData (ctx, chunk, callback) =>
      responseChunks.push chunk
      callback()

    ctx.onResponseEnd (ctx, callback) =>
      buffer = @handleResponse Buffer.concat(responseChunks), session

      ctx.proxyToClientResponse.end buffer
      callback false

  handleRequest: (buffer, url) ->
    return [buffer] unless data = @parseProtobuf buffer, @requestEnvelope

    originalData = _.cloneDeep data

    session = @getSession(data, url)

    for handler in @requestEnvelopeHandlers
      data = if handler.length > 1
        handler(session.data, data) or data
      else
        handler(data) or data

    for request in data.requests
      rpcName = changeCase.pascalCase request.request_type
      proto = "POGOProtos.Networking.Requests.Messages.#{rpcName}Message"
      unless proto in POGOProtos.info()
        @log "[-] Request handler for #{rpcName} isn't implemented yet!"
        continue

      decoded = {}
      if request.request_message
        continue unless decoded = @parseProtobuf request.request_message, proto

      originalRequest = _.cloneDeep decoded
      afterHandlers = @handleRequestAction session, rpcName, decoded

      # disabled since signature validation
      # unless _.isEqual originalRequest, afterHandlers
      #   @log "[!] Overwriting #{rpcName} request
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

    session.setRequest data, url

    [buffer, session]


  handleResponse: (buffer, session) ->
    return buffer unless session and data = @parseProtobuf buffer, @responseEnvelope

    originalData = _.cloneDeep data

    for handler in @responseEnvelopeHandlers
      data = if handler.length > 1
        handler(session.data, data) or data
      else handler(data) or data

    for id, response of data.returns when response.length > 0
      unless id < session.lastRequest.requests.length
        @log "[-] Extra response #{id} with no matching request!"
        continue
      rpcName = changeCase.pascalCase session.lastRequest.requests[id].request_type
      proto = "POGOProtos.Networking.Responses.#{rpcName}Response"
      if proto in POGOProtos.info()
        continue unless decoded = @parseProtobuf response, proto

        originalResponse = _.cloneDeep decoded
        afterHandlers = @handleResponseAction session, rpcName, decoded
        unless _.isEqual afterHandlers, originalResponse
          @log "[!] Overwriting #{rpcName} response"
          data.returns[id] = POGOProtos.serialize afterHandlers, proto

        # disabled since signature validation
        # if injected and data.returns.length-injected-1 >= id
        #   # Remove a previously injected request to not confuse the client
        #   @log "[!] Removing #{rpcName} from response as it was previously injected"
        #   delete data.returns[id]

      else
        @log "[-] Response handler for #{rpcName} isn't implemented yet!"

    # Update session expiration and auth_ticket from response
    if id = session.setResponse(data)
      @refreshSession(session, id)

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


  getSession: (req, url) ->
    # use auth_ticket (if logged in) or token as id for this session
    id = if req.auth_ticket
      Buffer.concat [req.auth_ticket.start, req.auth_ticket.end]
      .toString()
    else if req.auth_info
      req.auth_info.token.contents

    unless id and session = @sessions[id]
      timestamp = Date.now()
      # check if this is a retried request with different auth token
      reqId = parseInt req.request_id
      for i, s of @sessions
        if s.lastRequest.request_id is reqId
          session = s
        # do some housekeeping on old sessions
        if s.expiration < timestamp
          delete @sessions[i]
      # create a new session if not found (id can be undefined)
      session = new Session id, url unless session

    # set last request
    if id = session.setRequest req, url
      @sessions[id] = session

    session

  refreshSession: (session, newId) ->
    delete @sessions[session.id] if session.id
    @sessions[newId] = session
    session.id = newId

  handleRequestAction: (session, action, data) ->
    @log "[+] Request for action #{action}: "
    @logData data if data

    handlers = [].concat @requestHandlers[action] or [], @requestHandlers['*'] or []
    for handler in handlers
      data = if handler.length > 2
        handler(session.data, data, action) or data
      else
        handler(data, action) or data

    data

  handleResponseAction: (session, action, data) ->
    @log "[+] Response for action #{action}"
    @logData data if data

    handlers = [].concat @responseHandlers[action] or [], @responseHandlers['*'] or []
    for handler in handlers
      data = if handler.length > 2
        handler(session.data, data, action) or data
      else
        handler(data, action) or data

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
          
  #         @logData data
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

  parseProtobuf: (buffer, schema) ->
    try
      return POGOProtos.parseWithUnknown buffer, schema
    catch e
      @log "[-] Parsing protobuf of #{schema} failed: #{e}"

  log: (text) ->
    console.log text if @debug

  logData: (text) ->
    console.log JSON.stringify(text, null, 4) if @debug

module.exports = PokemonGoMITM
