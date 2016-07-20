###
  Pokemon Go (c) MITM node proxy
  by Michael Strassburger <codepoet@cpan.org>
###

Proxy = require 'http-mitm-proxy'
POGOProtos = require 'pokemongo-protobuf'
changeCase = require 'change-case'
fs = require 'fs'
_ = require 'lodash'

class PokemonGoMITM
  responseEnvelope: 'POGOProtos.Networking.Envelopes.ResponseEnvelope'
  requestEnvelope: 'POGOProtos.Networking.Envelopes.RequestEnvelope'

  requestHandlers: {}
  responseHandlers: {}
  requestEnvelopeHandlers: []
  responseEnvelopeHandlers: []

  messageInjectQueue: []

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

      originalData = _.cloneDeep data

      for handler in @requestEnvelopeHandlers
        data = handler(data, url: ctx.clientToProxyRequest.url) or data

      for id,request of data.requests
        protoId = changeCase.pascalCase request.request_type
      
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
  
      for message in @messageInjectQueue
        console.log "[+] Injecting request to #{message.action}"
        console.log message.data if message

        requested.push "POGOProtos.Networking.Responses.#{message.action}Response"
        data.requests.push
          request_type: changeCase.constantCase message.action
          request_message: POGOProtos.serialize message.data, "POGOProtos.Networking.Requests.Messages.#{message.action}Message"

      @messageInjectQueue = []

      @log "[+] Waiting for response..."
      
      unless _.isEqual originalData, data
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
      originalData = _.cloneDeep data

      for handler in @responseEnvelopeHandlers
        data = handler(data, {}) or data

      for id,response of data.returns
        proto = requested[id]
        if proto in POGOProtos.info()
          decoded = POGOProtos.parse response, proto
          
          protoId = proto.split(/\./).pop().split(/Response/)[0]

          if overwrite = @handleResponse protoId, decoded
            @log "[!] Overwriting "+protoId
            data.returns[id] = POGOProtos.serialize overwrite, proto

        else
          @log "[-] Response handler for #{requested[id]} isn't implemented yet.."

      # Overwrite the response in case a hook hit the fan
      unless _.isEqual originalData, data
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

    handlers = [].concat @requestHandlers[action] or [], @requestHandlers['*'] or []
    for handler in handlers
      data = handler(data, action) or data

      return data

    false

  handleResponse: (action, data) ->
    @log "[+] Response for action #{action}"
    @log data if data

    handlers = [].concat @responseHandlers[action] or [], @responseHandlers['*'] or []
    for handler in handlers
      data = handler(data, action) or data

      return data

    false

  injectMessage: (action, data) ->
    unless "POGOProtos.Networking.Requests.Messages.#{action}Message" in POGOProtos.info()
      @log "[-] Can't inject action #{action} - proto not implemented"
      return

    @messageInjectQueue.push
      action: action
      data: data

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
