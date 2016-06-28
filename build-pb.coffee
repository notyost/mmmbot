# Description:
#   build an ansible playbook from github, put it on s3
#
# Configuration:
#   CREDSTASH_REF_GHTOKEN=mmmbot.github_token
#   CREDSTASH_REGION=us-west-2
#
# Commands:
#   hubot build-pb [example-tag] <https://github.com/mGageTechOps/example-playbook> <s3://example-path/ansible-playbook.tgz> - build an ansible playbook from github, put it on s3
#

build_upload = (robot, tag, url, s3_path, res) ->
  res.reply "building playbook..."
  url = url.replace("https://", "https://$(credstash -r #{process.env.CREDSTASH_REGION} get -n #{process.env.CREDSTASH_REF_GHTOKEN})@").replace(/\/$/, "")
  dir_path = url.substr(url.lastIndexOf('/') + 1)
  script = "git clone --branch #{tag} #{url}"
  script += " && cd #{dir_path} && git checkout #{tag} && ansible-galaxy install -r requirements.yml -p ./roles &&  tar -cvzf ../#{dir_path}.tgz . && cd .. &&"
  script += " aws s3 cp #{dir_path}.tgz #{s3_path} &&"
  script += " rm #{dir_path}.tgz && rm -rf #{dir_path}"
  shell = require('shelljs')
  shell.exec script, {async:true}, (code, output) ->
    if code != 0
      res.reply "Something went wrong -- I handled this situation by not handling it...¯\\_(ツ)_/¯"
    else
      if robot.adapterName != "slack"
        res.reply "Success, uploaded to: #{s3_path}"
      else
        p_output = output.match(/upload.*/)
        robot.emit 'slack-attachment',
          channel: "#{res.message.user.room}"
          content:
            text: "#{p_output}"
            title: ":rocket: built playbook & uploaded to s3 :100: :shipit:"

module.exports = (robot) ->
  robot.respond /build-pb( .*)? (.*) (.*)/i, (res) ->
    tag = res.match[1]
    unless tag?
      tag = 'master'
    if /https.*/.test(res.match[2].trim())
      url = res.match[2].trim()
    else
      s3_path = res.match[2].trim()

    if /https.*/.test(res.match[3].trim())
      url = res.match[3].trim()
    else 
      s3_path = res.match[3].trim()
    build_upload(robot, tag, url, s3_path, res)
