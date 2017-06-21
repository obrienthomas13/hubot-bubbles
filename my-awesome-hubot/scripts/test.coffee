severStaging = false
idls = false
timeoutStart = null
# HUBOT_JENKINS_URL="https://leeroy.realtymogul.com/view/Pre-Qual%20Services/job/This%20is%20a%20test%20job,%20kindly%20keep%20scrolling.../buildWithParameters?token=P1E7keYzMr"
# HUBOT_JENKINS_AUTH=""
# # currentUser = ""
#
#
# jenkinsBuild = (msg, buildWithEmptyParameters) ->
#     url = process.env.HUBOT_JENKINS_URL
#     job = querystring.escape msg.match[1]
#     params = msg.match[3]
#     command = if buildWithEmptyParameters then "buildWithParameters" else "build"
#     path = if params then "#{url}/job/#{job}/buildWithParameters?#{params}" else "#{url}/job/#{job}/#{command}"
#
#     req = msg.http(path)
#
#     if process.env.HUBOT_JENKINS_AUTH
#       auth = new Buffer(process.env.HUBOT_JENKINS_AUTH).toString('base64')
#       req.headers Authorization: "Basic #{auth}"
#
#     req.header('Content-Length', 0)
#     req.post() (err, res, body) ->
#         if err
#           msg.reply "Jenkins says: #{err}"
#         else if 200 <= res.statusCode < 400 # Or, not an error code.
#           msg.reply "(#{res.statusCode}) Build started for #{job} #{url}/job/#{job}"
#         else if 400 == res.statusCode
#           jenkinsBuild(msg, true)
#         else if 404 == res.statusCode
#           msg.reply "Build not found, double check that it exists and is spelt correctly."
#         else
#           msg.reply "Jenkins says: Status #{res.statusCode} #{body}"


module.exports = (robot) ->
  robot.hear /Why can't I print/i, (res) ->
    res.send "Have you checked the reverse proxy?"

  robot.respond /, what is the best album by The Beatles\?*/i, (res) ->
    res.send "http://d817ypd61vbww.cloudfront.net/sites/default/files/styles/media_responsive_widest/public/tile/image/AbbeyRoad.jpg?itok=BgfH98zh"

  robot.respond /, initialize a deploy and lockdown staging/i, (res) ->
    if severStaging
      res.reply "Staging has already been severed. ABORTING!"
    else
      res.reply "You sure? (yes/no)"
      idls = true
      timeoutStart = setTimeout (->
        if idls
          idls = false
          res.reply "Timeout"
      )
      , 5 * 1000


  robot.hear /yes/i, (res) ->
    if idls
      idls = false
      severStaging = true;
      res.reply "Good luck"
      res.send "Beginning to initialize a deploy and severing staging"
      res.jenkins
      res.send "Post build"
      # curl -v "https://leeroy.realtymogul.com/view/Pre-Qual%20Services/job/This%20is%20a%20test%20job,%20kindly%20keep%20scrolling.../buildWithParameters?token=P1E7keYzMr"

  robot.hear /no/i, (res) ->
    if idls
      idls = false
      res.reply "ABORT"

  robot.respond /, reconnect to staging/i, (res) ->
    res.reply "Reconnecting to staging..."
    if severStaging
      severStaging = false
      res.reply "Reconnected!"
    else
      res.reply "Already connected to staging"
