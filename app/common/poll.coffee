class @Poll

  constructor: (args) ->
    args ?= {}
    args = _.defaults(args, {
      pollFreq: 1000
    })
    console.log args
    @pollFreq = args.pollFreq

  pollJob: (jobId) ->
    df = $.Deferred()
    pollFreq = @pollFreq
    console.log('Polling job', jobId, 'freq', pollFreq);
    pollJob = ->
      Meteor.call 'catalyst/assets/poll', jobId, (err, job) ->
        if err
          console.error('Unable to get job.', err)
          df.reject(err)
        else if job
          console.log('Job response', jobId, job)
          # TODO(aramk) Unsure why these both exist.
          status = job.status ? job.body?.status
          if status && status.toLowerCase() == 'fail'
            df.reject(job)
          else
            df.resolve(job)
        else
          console.log('Still Poll job', jobId)
          setTimeout(pollJob, pollFreq)
    pollJob()
    df
