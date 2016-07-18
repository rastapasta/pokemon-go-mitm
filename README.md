# pokemon-go-mitm-node
Pokemon Go MITM Proxy - Intercepts the traffic between your Pokemon Go App and their servers, decodes the protocol and gives you an handy tool to enrich your own game experience by altering the data on the fly.


![screenshot](https://files.slack.com/files-pri/T1R4G4SH1-F1SHL752S/bildschirmfoto_2016-07-18_um_09.35.29.png?pub_secret=04cbc25c54)

## How to use it?
* **npm install**
* **coffee server.coffee**
* Run it once to get a CA certificate generated
* Copy .http-mitm-proxy/certs/ca.pem to your Android device
* Add it to "trusted certificates"
* Setup your connection to use your server as a proxy (default port is 8081)
* Enjoy :)
