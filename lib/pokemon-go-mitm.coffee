###
  Pokemon Go (c) MITM node proxy
  by Michael Strassburger <codepoet@cpan.org>
###

Proxy = require 'http-mitm-proxy'
POGOProtos = require 'pokemongo-protobuf'
upperCamelCase = require 'uppercamelcase'
fs = require 'fs'

class PokemonGoMITM
  responseEnvelope: 'POGOProtos.Networking.Envelopes.ResponseEnvelope'
  requestEnvelope: 'POGOProtos.Networking.Envelopes.RequestEnvelope'

  requestHandlers: {}
  responseHandlers: {}

  constructor: (options) ->
    @port = options.port or 8081
    @debug = options.debug or false
    @setupProxy()

  setupProxy: ->
    proxy = Proxy()
    proxy.use Proxy.gunzip
    proxy.onRequest @handleProxyRequest
    proxy.onError @handleProxyError
    proxy.listen port: @port
    console.log "[+++] PokemonGo MITM Proxy listening on #{@port}"
    console.log "[!] Make sure to have the CA cert .http-mitm-proxy/certs/ca.pem installed on your device"

  handleProxyRequest: (ctx, callback) =>
    # don't interfer with anything not going to the Pokemon API
    return callback() unless ctx.clientToProxyRequest.headers.host is "pgorelease.nianticlabs.com"

    @log "[+++] Request to #{ctx.clientToProxyRequest.url}"

    ### Client Reuqest Handling ###
    requestChunks = []
    ctx.onRequestData (ctx, chunk, callback) =>
      requestChunks.push chunk
      callback null, null

    requested = []
    ctx.onRequestEnd (ctx, callback) =>
      buffer = Buffer.concat requestChunks
      data = POGOProtos.parse buffer, @requestEnvelope
      recode = false

      for id,request of data.requests
        protoId = upperCamelCase request.request_type
      
        # Queue the ProtoId for the response handling
        requested.push "POGOProtos.Networking.Responses.#{protoId}Response"
        
        proto = "POGOProtos.Networking.Requests.Messages.#{protoId}Message"
        unless proto in POGOProtos.info()
          @log "[-] Request handler for #{protoId} isn't implemented yet.."
          continue

        decoded = if request.request_message
          POGOProtos.parse request.request_message, proto
        else {}
        
        if overwrite = @handleRequest protoId, decoded
          @log "[!] Overwriting "+proto
          request.request_message = POGOProtos.serialize overwrite, proto
          recode = true
  
      @log "[+] Waiting for response..."
      
      if recode
        buffer = POGOProtos.serialize data, @requestEnvelope
      
      ctx.proxyToServerRequest.write buffer
      callback()

    ### Server Response Handling ###
    responseChunks = []
    ctx.onResponseData (ctx, chunk, callback) =>
      responseChunks.push chunk
      callback()

    ctx.onResponseEnd (ctx, callback) =>
      buffer = Buffer.concat responseChunks
      data = POGOProtos.parse buffer, @responseEnvelope
      recode = false

      for id,response of data.returns
        proto = requested[id]
        if proto in POGOProtos.info()
          decoded = POGOProtos.parse response, proto
          
          protoId = proto.split(/\./).pop().split(/Response/)[0]

          if overwrite = @handleResponse protoId, decoded
            @log "[!] Overwriting "+protoId
            data.returns[id] = POGOProtos.serialize overwrite, proto
            recode = true

        else
          @log "[-] Response handler for #{requested[id]} isn't implemented yet.."

      # Overwrite the response in case a hook hit the fan
      if recode
        buffer = POGOProtos.serialize data, @responseEnvelope

      ctx.proxyToClientResponse.end buffer

      callback false

    callback()

  handleProxyError: (ctx, err, errorKind) =>
    url = if ctx and ctx.clientToProxyRequest then ctx.clientToProxyRequest.url else ''
    console.error errorKind + ' on ' + url + ':', err

  handleRequest: (action, data) ->
    @log "[+] Request for action #{action}: "
    @log data if data

    if @requestHandlers[action]
      return @requestHandlers[action] data

    false

  handleResponse: (action, data) ->
    @log "[+] Response for action #{action}"
    @log data if data

    if @responseHandlers[action]
      return @responseHandlers[action] data

    false

  setResponseHandler: (action, cb) ->
    @responseHandlers[action] = cb
    this

  setRequestHandler: (action, cb) ->
    @requestHandlers[action] = cb
    this

  log: (text) ->
    console.log text if @debug

module.exports = PokemonGoMITM
