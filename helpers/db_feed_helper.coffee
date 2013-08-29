module.exports = class Feed

    db:       undefined
    feed:     undefined
    axonSock: undefined

    constructor: (@app) ->
        @startPublishingToAxon()

        @logger = @app.compound.logger
        @app.compound.server.on 'close', =>
            @stopListening()
            @axonSock.close()  if @axonSock?

    # define input craddle connection
    # db the craddle connection
    startListening: (db) ->
        @stopListening()
        @feed = db.changes since:'now'
        @feed.on 'change', @_onChange
        @feed.on 'error', (err) =>
            console.log "Error occured with feed : #{err.stack}"
            @stopListening()

        @db = db

    # stop listenning to changes
    stopListening: ->
        if @feed?
            @feed.stop()
            @feed.removeAllListeners 'change'
            @feed = null
        if @db?
            @db = null

    startPublishingToAxon: (attempt = 0) ->
        axon = require 'axon'
        @axonSock = axon.socket 'pub-emitter'
        @axonSock.bind 9105
        console.log 'Pub server started'

        @axonSock.sock.on 'connect', () ->
            console.info "An application conected to the change feeds"

    publish: (event, id) => @_publish(event, id)


    # [INTERNAL] publish to available outputs
    _publish: (event, id) ->
        console.info "Publishing #{event} #{id}"
        @axonSock.emit event, id if @axonSock?

    # [INTERNAL]  transform db change to (doctype.op, id) message and publish
    _onChange: (change) =>
        return if change.deleted #delete events are send by data controller

        isCreation = change.changes[0].rev.split('-')[0] is '1'
        operation = if isCreation then 'create' else 'update'

        @db.get change.id, (err, doc) =>
            console.log err if err?
            doctype = doc?.docType?.toLowerCase()
            @_publish "#{doctype}.#{operation}", doc._id if doctype

    usage: (app) ->
        @_publish "usage.application", app
