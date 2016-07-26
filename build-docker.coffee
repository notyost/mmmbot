# Description:
#   build an ansible playbook from github, put it on s3
#
# Configuration:
#   CREDSTASH_REF_GHTOKEN=mmmbot.github_token
#   CREDSTASH_REGION=us-west-2
#
# Commands:
#   hubot build-docker [example-tag] <https://github.com/mGageTechOps/example-playbook> <someaccountid.dkr.ecr.us-west-2.amazonaws.com/somerepo> - build a docker imagefrom a github repo and push it to ecr
#

docker_build = (robot, tag, url, ecr_path, res) ->
  res.reply "building docker image..."
  url = url.replace("https://", "https://$(credstash -r #{process.env.CREDSTASH_REGION} get -n #{process.env.CREDSTASH_REF_GHTOKEN})@").replace(/\/$/, "")
  dir_path = url.substr(url.lastIndexOf('/') + 1)
  script = "git clone --branch #{tag} #{url}"
  script += " && cd #{dir_path} && git checkout #{tag} && eval $(aws --region #{process.env.CREDSTASH_REGION} ecr get-login)"
  script += " && docker build --force-rm=true -t #{ecr_path} . && docker push #{ecr_path}"
  script += " && docker rmi -f #{ecr_path}"
  script += " && rm #{dir_path}.tgz && rm -rf #{dir_path}"
  shell = require('shelljs')
  shell.exec script, {async:true}, (code, output) ->
    if code != 0
      res.reply "Something went wrong -- I handled this situation by not handling it...¯\\_(ツ)_/¯"
    else
      if robot.adapterName != "slack"
        res.reply "Success, pushed to #{ecr_path}"
      else
        robot.emit 'slack-attachment',
          channel: "#{res.message.user.room}"
          content:
            text: "#{output}"
            title: ":rocket: built image and pushed to ecr :100: :shipit:"

module.exports = (robot) ->
  robot.respond /build-docker( .*)? (.*) (.*)/i, (res) ->
    tag = res.match[1]
    unless tag?
      tag = 'master'
    if /https.*/.test(res.match[2].trim())
      url = res.match[2].trim()
    else
      ecr_path = res.match[2].trim()

    if /https.*/.test(res.match[3].trim())
      url = res.match[3].trim()
    else 
      ecr_path = res.match[3].trim()
    docker_build(robot, tag, url, ecr_path, res)
