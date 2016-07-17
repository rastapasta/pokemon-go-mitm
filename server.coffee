###
  Pokemon Go (c) MITM node proxy
###

Proxy = require 'http-mitm-proxy'

# TODO: figure out the optimal protbuf lib
protobuf = require 'protobufjs'

# previously tried but with bad handling of unknown protbuf fields:
# protobuf = require 'protocol-buffers'
# protobuf = require 'node-protobuf'

fs = require 'fs'

port = 8081

# Initiate the protbuf definitions
builder = protobuf.loadProtoFile 'pokemon.proto'
pokemonProto = builder.build()
RequestEnvelop = pokemonProto.RequestEnvelop
ResponseEnvelop = pokemonProto.ResponseEnvelop

# Setup the MITM proxy
proxy = Proxy()
proxy.use Proxy.gunzip

proxy.onRequest (ctx, callback) ->
  # don't interfer with anything not going to the Pokemon API
  return callback() unless ctx.clientToProxyRequest.headers.host is "pgorelease.nianticlabs.com"

  console.log "REQUEST: #{ctx.clientToProxyRequest.url}"

  ### Client Reuqest Handling ###
  requestChunks = []
  ctx.onRequestData (ctx, chunk, callback) ->
    requestChunks.push chunk
    callback()

  ctx.onRequestEnd (ctx, callback) ->
    data = decodeData RequestEnvelop, Buffer.concat requestChunks
    console.log "request", data

    # TODO: inject changes before forwarding request
    callback()

  ### Server Response Handling ###
  responseChunks = []
  ctx.onResponseData (ctx, chunk, callback) ->
    responseChunks.push chunk
    callback()

  ctx.onResponseEnd (ctx, callback) ->
    data = decodeData ResponseEnvelop, Buffer.concat responseChunks
    console.log "response", data

    # TODO: inject changes before forwarding response
    ctx.proxyToClientResponse.write request
    callback()

  callback()

proxy.onError (ctx, err, errorKind) ->
  url = if ctx and ctx.clientToProxyRequest then ctx.clientToProxyRequest.url else ''
  console.error errorKind + ' on ' + url + ':', err


decodeData = (scheme, data) ->
  try
    decoded = RequestEnvelop.decode data
  catch e
    console.warn "[-] parsing protbuf buffer failed: #{e}"
    if e.decoded
      console.warn "[+] though it got partialy decoded"
      decoded = e.decoded
    else
      console.warn "[-] and nothing got decoded"
  decoded


proxy.listen port: port
console.log "[+] listening on #{port}"


