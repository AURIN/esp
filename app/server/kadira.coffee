env = process.env
if env.ADIRA_APP_ID && env.KADIRA_APP_SECRET
  Kadira.connect(env.ADIRA_APP_ID, env.KADIRA_APP_SECRET)
  Logger.info('Connecting to Kadira')
