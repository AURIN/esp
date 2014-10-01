class @Poll

  constructor: (args) ->
    args ?= {}
    args = _.defaults(args, {
      pollFreq: 1000
    })
    @pollFreq = args.pollFreq

  pollJob: (jobId) ->
    df = Q.defer()
    pollFreq = @pollFreq
    console.log('Polling job', jobId, 'freq', pollFreq);
    pollJob = Meteor.bindEnvironment ->
      Meteor.call 'assets/poll', jobId, (err, job) ->
        if err
          console.error('Unable to get job.', err)
          df.reject(err)
        else if job
          console.log('Job response', jobId, job)
          # TODO(aramk) Unsure why these both exist.
          status = job.status ? job.body?.status
          if status && status.toLowerCase() == 'fail'
            console.log('Job failed')
            df.reject(job)
          else
            df.resolve(job)
        else
          console.log('Still Poll job', jobId)
          setTimeout(pollJob, pollFreq)
    pollJob()
    df.promise
