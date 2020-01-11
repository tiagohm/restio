const express = require('express')
const fs = require('fs')
const https = require('https')

const credentials = {
    key: fs.readFileSync('./test/node/ca/certs/server.key'),
    cert: fs.readFileSync('./test/node/ca/certs/server.crt'),
    passphrase: '123mudar',
    requestCert: true,
    rejectUnauthorized: false,
    ca: [fs.readFileSync("./test/node/ca/certs/server.crt")],
}

const app = express()

app.all('*', (req, res, next) => {
    const cert = req.connection.getPeerCertificate()

    console.log(cert)

    if (req.client.authorized) {
        next();
    } else if (cert.subject) {
        res.status(403).send(`Sorry ${cert.subject.CN}, certificates from ${cert.issuer.CN} are not welcome here.`)
    } else {
        res.status(401).send(`Sorry, but you need to provide a client certificate to continue.`)
    }
})

app.get('/', (req, res) => {
    const cert = req.connection.getPeerCertificate()
    res.status(200).send(`Olá ${cert.subject.CN}!`)
})

const server = https.createServer(credentials, app)

server.listen(3002, () => console.log(`HTTPS Server running at port 3002!`))