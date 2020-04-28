const express = require('express')
const SSE = require('express-sse')

const sse = new SSE()
const app = express()
let id = 1

app.get('/', (req, res) => {
    const reqId = id++

    console.log(`New connection: ${reqId}`)

    sse.init(req, res)

    let data = 1

    const interval = setInterval(() => {
        console.log(`Sending data to ${reqId}: ${data}...`)
        sse.send(data, 'counter')
        data++
    }, 1000)

    res.addListener('close', () => {
        console.log(`Closed connection: ${reqId}`)
        clearInterval(interval)
    })
})

app.get('/closed-by-server', (req, res) => {
    const reqId = id++

    console.log(`New connection: ${reqId}`)

    sse.init(req, res)

    let data = 1

    const interval = setInterval(() => {
        console.log(`Sending data to ${reqId}: ${data}...`)
        sse.send(data, 'counter')
        data++

        if (data >= 5) {
            clearInterval(interval)
            res.socket.destroy()
        }
    }, 1000)

    res.addListener('close', () => {
        console.log(`Closed connection: ${reqId}`)
        clearInterval(interval)
    })
})

app.listen(3000, () => console.log('SSE running at port 3000!'))

