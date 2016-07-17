# pokemon-go-mitm-node
Pokemon Go MITM Proxy - based on node.js

## How to use it?
* **npm install**
* **coffee server.coffee**
* Run it once to get a CA certificate generated
* Copy .http-mitm-proxy/certs/ca.pem to your Android device
* Add it to "trusted certificates"
* Setup your connection to use your server as a proxy (default port is 8081)
* Enjoy :)
