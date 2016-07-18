###
  Pokemon Go (c) MITM node proxy
###

Proxy = require 'http-mitm-proxy'
protobuf = require 'protobufjs'
upperCamelCase = require 'uppercamelcase'
fs = require 'fs'

port = 8081

# Initiate the protbuf definitions
rpcProto = protobuf.loadProtoFile('proto/rpc.proto').build()
RequestEnvelop = rpcProto.Holoholo.Rpc.RpcRequestEnvelopeProto
ResponseEnvelop = rpcProto.Holoholo.Rpc.RpcResponseEnvelopeProto

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
    callback null, chunk

  requested = []

  ctx.onRequestEnd (ctx, callback) ->
    buffer = Buffer.concat requestChunks
    data = decodeData RequestEnvelop, buffer
    
    for request in data.parameter
      requested.push getProtoFromKey request.key, false

      protoId = getProtoFromKey request.key, true
      decoded = decodeData rpcProto.Holoholo.Rpc[protoId], request.value

      console.log "[+] Request for #{protoId}", decoded if decoded

    # TODO: inject changes before forwarding request
    callback()

  ### Server Response Handling ###
  responseChunks = []
  ctx.onResponseData (ctx, chunk, callback) ->
    responseChunks.push chunk
    callback null, chunk

  ctx.onResponseEnd (ctx, callback) ->
    buffer = Buffer.concat responseChunks

    data = decodeData ResponseEnvelop, buffer
    for id,response of data.returns
      decoded = decodeData rpcProto.Holoholo.Rpc[requested[id]], response.buffer
      console.log "[+] Response for #{requested[id]}: ", decoded if decoded

    # TODO: inject changes before forwarding response
    ctx.proxyToClientResponse.write buffer
    callback()

  callback()

proxy.onError (ctx, err, errorKind) ->
  url = if ctx and ctx.clientToProxyRequest then ctx.clientToProxyRequest.url else ''
  console.error errorKind + ' on ' + url + ':', err


decodeData = (scheme, data) ->
  try
    decoded = scheme.decode data
  catch e
    console.warn "[-] parsing protbuf buffer failed: #{e}"
    if e.decoded
      console.warn "[+] though it got partialy decoded"
      decoded = e.decoded
  decoded

getKeyByValue = (object, value) ->
  Object.keys(object).find (key) -> object[key] is value

getProtoFromKey = (key, request) ->
  upperCamelCase(getKeyByValue(rpcProto.Holoholo.Rpc.Method,key))+(if request then "Proto" else "OutProto")

proxy.listen port: port
console.log "[+] listening on #{port}"


