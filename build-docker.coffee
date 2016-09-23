# Description:
#   build a docker image and push it to ecr
#
# Configuration:
#   CREDSTASH_REF_GHTOKEN=mmmbot.github_token
#   CREDSTASH_REGION=us-west-2
#
# Commands:
#   hubot build-docker [example-tag] <https://github.com/mGageTechOps/example-playbook> <someaccountid.dkr.ecr.us-west-2.amazonaws.com/somerepo> - build a docker imagefrom a github repo and push it to ecr
#
shell = require('shelljs')

docker_build = (robot, tag, url, ecr_path, res) ->
  res.reply "attempting to build docker image @ #{url}:#{tag}..."
  clone_url = url.replace("https://", "https://$(credstash -r #{process.env.CREDSTASH_REGION} get -n #{process.env.CREDSTASH_REF_GHTOKEN})@").replace(/\/$/, "")
  dir_path = clone_url.substr(clone_url.lastIndexOf('/') + 1)
  script = [
    "git clone --branch #{tag} #{clone_url}",
    "cd #{dir_path}",
    "git checkout #{tag}",
    "eval $(aws --region #{process.env.CREDSTASH_REGION} ecr get-login)",
    "docker build --force-rm=true -t #{ecr_path} .",
    "docker push #{ecr_path}",
    "docker rmi -f #{ecr_path}",
    "cd .. && rm -rf #{dir_path}"
  ]
  shell.exec script.join('&& '), {async:true}, (code, output) ->
    if code != 0
      res.reply "Something went wrong -- I handled this situation by not handling it...¯\\_(ツ)_/¯"
    else
      if robot.adapterName == "slack"
        res.send {
          as_user: true
          attachments: [
            color: "good"
            pretext: "docker image built:"
            thumb_url: 'https://www.docker.com/sites/default/files/legal/small_v.png'
            fields: [
              { title: "ecr path", value: "#{ecr_path}", short: false}
              { title: "docker image", value: "#{url}", short: false }
              { title: "tag", value: "#{tag}", short: true }
            ]
          ]
        }
      else
        res.reply "Success, built #{url}:#{tag} and pushed to #{ecr_path}"

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
    docker_build(robot, tag, url, ecr_path, res) if url and ecr_path
