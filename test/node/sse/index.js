const express = require('express')
const SSE = require('express-sse')

const sse = new SSE()
const app = express()

app.get('/sse', sse.init)

let counter = 0

const interval = setInterval(() => {
    console.log(`Sending ${counter}...`)

    sse.send(counter++, 'counter')
}, 1000)

app.listen(3000, () => console.log('SSE running at port 3000!'))

