// 设置默认值
def DEFAULT_BUILD_PATH = './'
def DEFAULT_BUILD_COMMAND_JAVA = 'mvn clean package -DskipTests=true -U'
def DEFAULT_BUILD_COMMAND_NODE_v14 = 'npm install --registry=https://registry.npmmirror.com && npm run build'
def DEFAULT_BUILD_COMMAND_NODE_v16 = 'yarn install --registry=https://registry.npmmirror.com && yarn run build'
def DEFAULT_BUILD_COMMAND_PYTHON = 'pip install -r requirements.txt -i https://mirrors.aliyun.com/pypi/simple/'
def DEFAULT_JAVA_TARGET_PATH = 'target/'

def DEFAULT_RUNNING_COMMAND_FRONTEND = 'nginx -g \\"daemon off;\\"'
def DEFAULT_RUNNING_COMMAND_JAVA = 'java -Dspring.profiles.active=${ENV} ${JAVA_OPTIONS} -jar app.jar'
def DEFAULT_RUNNING_COMMAND_PYTHON = 'python app.py'

pipeline {
	agent {
		label "${params.WORK_NODE}"
	}
	// 保持构建的最大个数
	options {
		buildDiscarder logRotator(artifactDaysToKeepStr: '', artifactNumToKeepStr: '', daysToKeepStr: '', numToKeepStr: '30')
	}

	// 将默认值设置成环境变量，让脚本可以使用
	environment {
		DEFAULT_BUILD_PATH = "${DEFAULT_BUILD_PATH}"
		DEFAULT_BUILD_COMMAND_JAVA = "${DEFAULT_BUILD_COMMAND_JAVA}"
		DEFAULT_BUILD_COMMAND_NODE_v14 = "${DEFAULT_BUILD_COMMAND_NODE_v14}"
		DEFAULT_BUILD_COMMAND_NODE_v16 = "${DEFAULT_BUILD_COMMAND_NODE_v16}"
		DEFAULT_BUILD_COMMAND_PYTHON = "${DEFAULT_BUILD_COMMAND_PYTHON}"
		DEFAULT_JAVA_TARGET_PATH = "${DEFAULT_JAVA_TARGET_PATH}"

		DEFAULT_RUNNING_COMMAND_FRONTEND = "${DEFAULT_RUNNING_COMMAND_FRONTEND}"
		DEFAULT_RUNNING_COMMAND_JAVA = "${DEFAULT_RUNNING_COMMAND_JAVA}"
		DEFAULT_RUNNING_COMMAND_PYTHON = "${DEFAULT_RUNNING_COMMAND_PYTHON}"
	}
	parameters {
		choice(name: 'WORK_NODE', choices: ['master', 'slave-1'], description: '选择执行任务的节点(来自节点列表标签)(首选 master 节点)')
		string(name: 'APP_TYPE', defaultValue: params.APP_TYPE, description: '【必填】\n应用类型，例如：java，node，python；通用应用填：app。')
		string(name: 'TYPE_VERSION', defaultValue: params.TYPE_VERSION, description: '【必填】\n应用类型版本号，例如：\njava代码的版本v1.8、v11，\nnode代码的版本v14、v16，\npython代码的版本v3.6、v3.8；\n通用应用设置与项目role内build.yaml定义的内容相对应，如：chain-mpbackend，chain-mpbackend-contract，chain-monitor，等。')
		string(name: 'BUILD_PATH', defaultValue: params.BUILD_PATH, description: "【选填】\n自定义打包路径目录，默认 ${DEFAULT_BUILD_PATH}")
		string(name: 'BUILD_COMMAND', defaultValue: params.BUILD_COMMAND, description: "【选填】\n自定义打包命令，默认：\njava: ${DEFAULT_BUILD_COMMAND_JAVA}\nnode_v14: ${DEFAULT_BUILD_COMMAND_NODE_v14}\nnode_v16: ${DEFAULT_BUILD_COMMAND_NODE_v16}\npython: ${DEFAULT_BUILD_COMMAND_PYTHON}")
		string(name: 'TARGET_PATH', defaultValue: params.TARGET_PATH, description: "【java】\n生成jar包目录，必须以/结尾，默认 ${DEFAULT_JAVA_TARGET_PATH}。")
		string(name: 'JAVA_OPTIONS', defaultValue: params.JAVA_OPTIONS, description: '【java】\n添加java启动额外参数')
		string(name: 'Dockerfile_EXTRA', defaultValue: params.Dockerfile_EXTRA, description: '【Dockerfile】\n自定义Dockerfile额外命令，位于CMD之前，多行命令使用\\n合并。')
		string(name: 'Dockerfile_CMD', defaultValue: params.Dockerfile_CMD, description: "【Dockerfile】\n自定义应用启动命令，默认：\njava应用：${DEFAULT_RUNNING_COMMAND_JAVA}\n前端应用：${DEFAULT_RUNNING_COMMAND_FRONTEND}\npython应用：${DEFAULT_RUNNING_COMMAND_PYTHON}")
		string(name: 'CODE_URL', defaultValue: params.CODE_URL , description: '【必填】\n代码地址，修改后，“action”选择“config”，并点击“开始构建”后生效，下次再构建时即为更新后的代码地址。')
		string(name: 'GIT_AUTH', defaultValue: params.GIT_AUTH , description: '【必填】\n代码凭据“唯一标识”，codeup代码用‘tssl’。')
		listGitBranches(name: 'BRANCH', description: "选择分支，代码来自 ${params.CODE_URL}", branchFilter: '.*', credentialsId: "${params.GIT_AUTH}", defaultValue: params.BRANCH, listSize: '10', 
			remoteURL: params.CODE_URL, selectedValue: 'DEFAULT', sortMode: 'ASCENDING_SMART', tagFilter: '*', type: 'PT_BRANCH_TAG')
		choice(name: 'action', description: '执行动作：\n config - 更新jenkins配置\n build - 只进行打包编译\n deploy - 更新部署服务', choices: ['config', 'build', 'deploy'])
		string(name: 'DEPLOY_TYPE', defaultValue: params.DEPLOY_TYPE, description: '【必填】\n部署类型，选择如下: \nkubernetes  - 以更新镜像tag的方式发布\ndocker-compose  - 以更新镜像tag的方式发布\nresource  - 以更新文件的方式发布')
		booleanParam(name: 'NOTICE', defaultValue: true, description: '是否发送通知？\n默认勾选，同时要求项目config.yaml配置中“notice”配置为“true”，即发送通知，\n否则无法发送通知。')
		string(name: 'INSTRUCTION', description: '【选填】\n说明此次发布的目的。')
	}

	stages {
		stage('update') {
			when {
				environment name: 'action',value: 'config'
			}
			steps {
				unstable("【配置更新成功！】")
			}
		}

		stage('下载代码') {
			when {
				anyOf {
					environment name: 'action',value: 'build'
					environment name: 'action',value: 'deploy'
				}
			}
			steps {
				dir("sourcecode/"){
					checkout(
						[$class: 'GitSCM', doGenerateSubmoduleConfigurations: false, submoduleCfg: [], extensions: [[$class: 'CloneOption', depth: 1, noTags: false, reference: '', shallow: true]],
						branches: [[name: "${params.BRANCH}"]],userRemoteConfigs: [[url: "${params.CODE_URL}", credentialsId: "${params.GIT_AUTH}"]]]
						)
				}
			}
		}
		stage('构建') {
			when {
				anyOf {
					environment name: 'action',value: 'build'
					environment name: 'action',value: 'deploy'
				}
			}
			steps {
				script {
					sh '''
						set -e
						bash run.sh build
						bash -x run_build.sh
					'''
				}
			}
		}

		stage('部署') {
			when {
				environment name: 'action',value: 'deploy'
			}
			steps {
				script {
					sh '''
						set -e
						bash run.sh deploy
						bash -x run_deploy.sh
					'''
				}
			}
		}
	}
	// 发送通知
	post {
		// 人为中断
		aborted {
			wrap([$class: 'BuildUser']) {
				script {
					env.durationString = currentBuild.durationString
					env.fullDisplayName = currentBuild.fullDisplayName
					env.currentResult = currentBuild.currentResult
					sh '''
						set -e
						bash run.sh notice
					'''
				}
			}
		}
		// 构建失败
		failure {
			wrap([$class: 'BuildUser']) {
				script {
					env.durationString = currentBuild.durationString
					env.fullDisplayName = currentBuild.fullDisplayName
					env.currentResult = currentBuild.currentResult
					sh '''
						set -e
						bash run.sh notice
						'''
				}
			}
		}
		// 构建成功
		success {
			wrap([$class: 'BuildUser']) {
				script {
					env.durationString = currentBuild.durationString
					env.fullDisplayName = currentBuild.fullDisplayName
					env.currentResult = currentBuild.currentResult
					sh '''
						set -e
						bash run.sh notice
						'''
				}
			}
		}
	}
}
