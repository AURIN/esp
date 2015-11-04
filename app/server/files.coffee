Meteor.methods

  # Finds files which no longer exist and are referenced in typologies and entities.
  'files/missing-refs': ->
    AccountsUtil.authorizeUser @userId, (user) -> AccountsUtil.isAdmin(user)

    Logger.info('Finding missing file references...')
    @unblock()

    fileIdMap = {}
    fields = ["#{ParamUtils.prefix}.space.geom_2d", "#{ParamUtils.prefix}.space.geom_3d"]

    selector = $or: _.map fields, (field) ->
      orSelector = {}
      orSelector[field] = {$exists: true}
      orSelector

    maybeIncludeDoc = (doc, collection) ->
      for field in fields
        value = Objects.getModifierProperty(doc, field)
        if Files.findOne(value)
          fileInfo =
            fileId: value
            docId: doc._id
            collectionId: Collections.getName(collection)
          docName = doc.name
          if docName then fileInfo.docName = docName
          projectId = doc.project
          project = Projects.findOne(projectId) if projectId?
          if projectId?
            _.extend fileInfo,
              projectId: project._id
              projectName: project.name
              inTemplate: !!project.isTemplate
          fileIdMap[value] = fileInfo
          return

    Typologies.find(selector).forEach (doc) -> maybeIncludeDoc(doc, Typologies)
    Entities.find(selector).forEach (doc) -> maybeIncludeDoc(doc, Entities)

    fileIds = _.keys(fileIdMap)
    fileCount = _.size(fileIds)
    if fileCount == 0
      Logger.info "Found no files to check"
    else
      Logger.info "Found #{fileCount} files to check..."

    # TODO(aramk) For testing
    # fileIds = fileIds.slice(0, 5)

    deferredQueue = new DeferredQueue()
    fileIdBuckets = Arrays.buckets(fileIds, 50)
    dfs = {}
    missingIds = {}
    _.each fileIdBuckets, (ids) ->
      deferredQueue.add ->
        promises = []
        _.each ids, (id) ->
          dfs[id] = df = Q.defer()
          # Delay to avoid exceeding API limit.
          _.delay Meteor.bindEnvironment ->
            file = Files.findOne(id)
            key = file?.copies['files-S3']?.key
            unless key then return df.resolve "Skipping file #{id} - no S3 key found"
            df.resolve S3Utils.exists('aurin-esp', key).then (exists) ->
              unless exists
                Logger.info "File doesn't exist: #{id} #{key}", fileIdMap[id]
                missingIds[id] = true
          , 200
          promises.push df.promise
        Q.all(promises)

    deferredQueue.waitForAllSync Meteor.bindEnvironment ->
      if _.isEmpty(missingIds) then return Logger.info('No missing files found')

      missingIdsInfo = []
      _.each missingIds, (value, id) ->
        missingIdsInfo.push fileIdMap[id]
      Logger.info 'Missing file IDs', missingIdsInfo
