const WebSocket = require('ws')

const ws = new WebSocket.Server({ port: 3001 })

ws.on('connection', (ws) => {
    ws.on('message', (message) => {
        console.log(`Received: ${message}`)

        if (message == 'close') {
            ws.close(4000, 'Closed by server')
        } else {
            ws.send(message)
        }
    })

    ws.on('close', (code, reason) => {
        console.log(`Connection closed: ${code} ${reason}`)
    })
})