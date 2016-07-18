###
  Pokemon Go (c) MITM node proxy

  (c) by 
###

Proxy = require 'http-mitm-proxy'
protobuf = require 'node-protobuf'
upperCamelCase = require 'uppercamelcase'
fs = require 'fs'

class PokemonGoMITM
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
      data = @POGOProtos.parse buffer, "POGOProtos.Networking.Envelopes.RequestEnvelope"
      for request in data.requests
        protoId = upperCamelCase request.request_type
      
        # Queue the ProtoId for the response handling
        requested.push "POGOProtos.Networking.Responses.#{protoId}Response"
        
        decoded = if request.request_message
          @POGOProtos.parse request.request_message, "POGOProtos.Networking.Requests.Messages.#{protoId}Message"
        else {}
        
        console.log "[+] Request for #{protoId}", decoded

      console.log "[+] Waiting for response..."
      # TODO: inject changes before forwarding request
      callback()

    ### Server Response Handling ###
    responseChunks = []
    ctx.onResponseData (ctx, chunk, callback) =>
      responseChunks.push chunk
      callback null, chunk

    ctx.onResponseEnd (ctx, callback) =>
      buffer = Buffer.concat responseChunks
      data = @POGOProtos.parse buffer, "POGOProtos.Networking.Envelopes.ResponseEnvelope"

      for id,response of data.returns
        proto = requested[id]
        if proto in @POGOProtos.info()
          decoded = @POGOProtos.parse response, proto
          console.log "[+] Response for #{proto}: ", decoded
        else
          console.log "[-] Response handler for #{requested[id]} not implemented yet.."

      # TODO: inject changes before forwarding response
      ctx.proxyToClientResponse.write buffer
      callback()

    callback()

  handleProxyError: (ctx, err, errorKind) =>
    url = if ctx and ctx.clientToProxyRequest then ctx.clientToProxyRequest.url else ''
    console.error errorKind + ' on ' + url + ':', err

module.exports = PokemonGoMITM