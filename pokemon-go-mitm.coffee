###
  Pokemon Go (c) MITM node proxy

  (c) by 
###

Proxy = require 'http-mitm-proxy'
protobuf = require 'node-protobuf'
upperCamelCase = require 'uppercamelcase'
fs = require 'fs'

class PokemonGoMITM
  responseEnvelope: 'POGOProtos.Networking.Envelopes.ResponseEnvelope'
  requestEnvelope: 'POGOProtos.Networking.Envelopes.RequestEnvelope'

  constructor: (@port) ->
    throw "[-] No port given" unless @port

    # Init the Protobuf engine with the beautiful
    # Protos from https://github.com/AeonLucid/POGOProtos
    @POGOProtos = new protobuf fs.readFileSync "POGOProtos.desc"

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

    console.log "[+++] Request to #{ctx.clientToProxyRequest.url}"

    ### Client Reuqest Handling ###
    requestChunks = []
    ctx.onRequestData (ctx, chunk, callback) =>
      requestChunks.push chunk
      callback null, chunk

    requested = []
    ctx.onRequestEnd (ctx, callback) =>
      buffer = Buffer.concat requestChunks
      data = @POGOProtos.parse buffer, @requestEnvelope
      recode = false

      for id,request of data.requests
        protoId = upperCamelCase request.request_type
      
        # Queue the ProtoId for the response handling
        requested.push "POGOProtos.Networking.Responses.#{protoId}Response"
        
        proto = "POGOProtos.Networking.Requests.Messages.#{protoId}Message"
        unless proto in @POGOProtos.info()
          console.log "[-] Request handler for #{protoId} isn't implemented yet.."
          continue

        decoded = if request.request_message
          @POGOProtos.parse request.request_message, proto
        else {}
        
        if overwrite = @handleMessage protoId, decoded
          console.log "[!] Overwriting "+proto+" with ", decoded
          data[id] = @POGOProtos.serialize overwrite, proto
          recode = true
  
      console.log "[+] Waiting for response..."
      
      if recode
        buffer = @POGOProtos.serialize data, @requestEnvelope

      # TODO: inject changes back into the POST body
      callback()

    ### Server Response Handling ###
    responseChunks = []
    ctx.onResponseData (ctx, chunk, callback) =>
      responseChunks.push chunk
      callback null, chunk

    ctx.onResponseEnd (ctx, callback) =>
      buffer = Buffer.concat responseChunks
      data = @POGOProtos.parse buffer, @responseEnvelope
      recode = false

      for id,response of data.returns
        proto = requested[id]
        if proto in @POGOProtos.info()
          decoded = @POGOProtos.parse response, proto
          
          protoId = proto.split(/\./).pop()

          if overwrite = @handleResponse protoId, decoded
            console.log "[!] Overwriting "+protoId+" with ", overwrite
            data.returns[id] = @POGOProtos.serialize overwrite, proto
            recode = true

        else
          console.log "[-] Response handler for #{requested[id]} isn't implemented yet.."

      # Overwrite the response in case a hook hit the fan
      if recode
        buffer = @POGOProtos.serialize data, @responseEnvelope

      ctx.proxyToClientResponse.end buffer
      callback()

    callback()

  handleProxyError: (ctx, err, errorKind) =>
    url = if ctx and ctx.clientToProxyRequest then ctx.clientToProxyRequest.url else ''
    console.error errorKind + ' on ' + url + ':', err

  handleMessage: (proto, data) ->
    console.log "[+] Request for action #{proto}: ", data
    return false

  handleResponse: (proto, data) ->
    console.log "[+] Response for action #{proto}: ", data
    return false

module.exports = PokemonGoMITM