# Description:
#   build an lambda function from github, put it on s3
#
# Configuration:
#   CREDSTASH_REF_GHTOKEN=mmmbot.github_token
#   CREDSTASH_REGION=us-west-2
#
# Commands:
#   mmmbot build-lambda [example-tag] <https://github.com/mGageTechOps/example-lambda> <s3://example-path/lambda.zip> - build an ansible playbook from github, put it on s3
#
shell = require('shelljs')

build_upload = (robot, tag, url, s3_path, res) ->
  res.reply "attempting to build lambda @ #{url}:#{tag}..."
  clone_url = url.replace('https://', "https://$(credstash -r #{process.env.CREDSTASH_REGION} get -n #{process.env.CREDSTASH_REF_GHTOKEN})@").replace(/\/$/, '')
  s3_path = s3_path.replace(/\.zip$/, '') + '.zip'
  dir_path = clone_url.substr(clone_url.lastIndexOf('/') + 1)
  script = [
    #clone the repo and switch to tag
    "ROOT_PATH=$(pwd)"
    "set -x"
    "git clone --branch #{tag} #{clone_url}"
    "cd #{dir_path}"
    "git checkout #{tag}"
    "cd $ROOT_PATH"
    #Make virtual env dir
    "mkdir venv"
    "rsync --exclude .git/ --exclude .gitignore -a #{dir_path}/ venv/"
    "cd $ROOT_PATH"
    "virtualenv venv"
    # Install requirements
    "source venv/bin/activate"
    "pip install -r venv/requirements.pip"
    "deactivate"
    #create archive
    "cd $ROOT_PATH/venv"
    "zip -9  $ROOT_PATH/#{dir_path}.zip *"
    "cd $ROOT_PATH/venv/lib/python2.7/site-packages"
    "zip -r9 $ROOT_PATH/#{dir_path}.zip *"
    "cd $ROOT_PATH"
    #copy archive to s3
    "aws s3 cp $ROOT_PATH/#{dir_path}.zip #{s3_path}"
    "rm #{dir_path}.zip && rm -rf venv  && rm -rf #{dir_path}"
  ]
  shell.exec script.join('&& '), {async:true}, (code, output) ->
    if code != 0
      res.reply "Something went wrong -- check the logs...\\_(ツ)_/, attempting cleanup"
      shell.exec "rm #{dir_path}.zip ; rm -rf venv ; rm -rf #{dir_path}", {async:true}
    else
      if robot.adapterName == "slack"
        res.send {
          as_user: true
          attachments: [
            color: "good"
            pretext: "playbook built:"
            thumb_url: 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/05/Ansible_Logo.png/64px-Ansible_Logo.png'
            fields: [
              { title: "s3 path", value: "#{s3_path}", short: false}
              { title: "lambda", value: "#{url}", short: false }
              { title: "tag", value: "#{tag}", short: true }
            ]
          ]
        }
      else
        res.reply "Success, built #{url}:#{tag} and uploaded to #{s3_path}"

module.exports = (robot) ->
  robot.respond /build-lambda( .*)? (.*) (.*)/i, (res) ->
    tag = res.match[1]
    unless tag?
      tag = 'master'
    if /https.*/.test(res.match[2].trim())
      url = res.match[2].trim()
    else if /s3.*/.test(res.match[2].trim())
      s3_path = res.match[2].trim()

    if /https.*/.test(res.match[3].trim())
      url = res.match[3].trim()
    else if /s3.*/.test(res.match[3].trim())
      s3_path = res.match[3].trim()

    build_upload(robot, tag, url, s3_path, res) if s3_path and url
