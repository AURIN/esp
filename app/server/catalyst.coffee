env = process.env
useLocalServer = env.ACS_ENV == 'local'

if useLocalServer
  console.log('Using local ACS server')

CATALYST_SERVER_LOCAL_URL = 'http://localhost/catalyst-server/'
CATALYST_SERVER_REMOTE_URL = 'http://infradev.eng.unimelb.edu.au/catalyst-server/'

CATALYST_SERVER_URL = if useLocalServer then CATALYST_SERVER_LOCAL_URL else
  CATALYST_SERVER_REMOTE_URL

LOGIN_URL = CATALYST_SERVER_URL + 'auth/login'
PROJECTS_URL = CATALYST_SERVER_URL + 'projects'

ASSETS_URL = CATALYST_SERVER_URL + 'assets/'
ASSET_UPLOAD_URL = ASSETS_URL + 'upload'
ASSET_DOWNLOAD_URL = ASSETS_URL + '{id}/download'
ASSET_FORMATS_URL = ASSETS_URL + 'formats'
ASSET_FORMATS_INPUT_URL = ASSETS_URL + 'formats/input'
ASSET_FORMATS_OUTPUT_URL = ASSETS_URL + 'formats/output'
ASSET_POLL_URL = ASSETS_URL + 'poll'
ASSET_SYNTHESIZE_URL = ASSETS_URL + 'synthesize'

C3ML_URL = CATALYST_SERVER_URL + 'c3ml/'
C3ML_DOWNLOAD_URL = C3ML_URL + '{id}/download'
META_DATA_URL = CATALYST_SERVER_URL + 'meta_data/'
META_DATA_DOWNLOAD_URL = META_DATA_URL + '{id}/download'

request = Meteor.npmRequire('request')

@Catalyst =

  auth:

    login: ->
      Request.call
        url: LOGIN_URL
        method: 'post'
        form: {username: env.CATALYST_USERNAME, password: env.CATALYST_PASSWORD}

  assets:

    upload: (buffer, args) ->
      Promises.runSync (done) ->
        r = request.post Request.mergeOptions({
          url: ASSET_UPLOAD_URL,
          jar: true
        }), (err, httpResponse, body) ->
          if err
            done(err, null)
            return
          try
            json = JSON.parse(body)
            done(null, json)
          catch e
            console.log('Error when parsing asset upload. Content was not JSON:', body)
            done(e, null)
        form = r.form()
        form.append('file', buffer, args)

    _downloadArgs: (id) ->
      url: @getDownloadUrl(id)
      method: 'get'

    download: (id) -> Request.call(@_downloadArgs(id))

    downloadJson: (id) -> Request.json(@_downloadArgs(id))

    downloadBuffer: (id) -> Request.buffer(@_downloadArgs(id))

    getDownloadUrl: (id) -> ASSET_DOWNLOAD_URL.replace('{id}', id)

    get: (id) ->
      Request.json
        url: ASSETS_URL + '/' + id
        method: 'get'

    inputFormats: ->
      Request.json
        url: ASSET_FORMATS_INPUT_URL
        method: 'get'

    formats: ->
      Request.json
        url: ASSET_FORMATS_URL
        method: 'get'

    outputFormats: ->
      Request.json
        url: ASSET_FORMATS_OUTPUT_URL
        method: 'get'

    synthesize: (request) ->
      Request.call
        url: ASSET_SYNTHESIZE_URL
        method: 'post'
        json: request

    poll: (jobId) ->
      Request.call
        url: ASSET_POLL_URL
        method: 'post'
        json: {uuid: jobId}

    c3ml:

      download: (id) ->
        Request.json
          url: C3ML_DOWNLOAD_URL.replace('{id}', id)
          method: 'get'

    metaData:

      download: (id) ->
        Request.json
          url: META_DATA_DOWNLOAD_URL.replace('{id}', id)
          method: 'get'

  projects:

    get: ->
      Request.json
        url: PROJECTS_URL
        method: 'get'
