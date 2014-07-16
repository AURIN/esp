@Files = new FS.Collection 'files', stores: [new FS.Store.FileSystem('files')]

Files.allow
  download: Collections.allow
  insert: Collections.allow
  update: Collections.allow
  remove: Collections.allow
