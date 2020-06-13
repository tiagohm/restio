const http = require('http')
const setup = require('proxy')
const basicAuthParser = require('basic-auth-parser')

// No Auth.

const noAuthProxy = http.createServer()
setup(noAuthProxy)

noAuthProxy.listen(3004, () => console.log(`Proxy Server running at port 3004!`))

// Auth.

const authProxy = http.createServer()
setup(authProxy)

authProxy.authenticate = function (req, fn) {
    const auth = req.headers['proxy-authorization']

    if (!auth) {
        return fn(null, false)
    }

    const parsed = basicAuthParser(auth)

    return fn(null, parsed.username === 'a' && parsed.password === 'b')
}

authProxy.listen(3005, () => console.log(`Auth Proxy Server running at port 3005!`))