#!/usr/bin/env bash

set -e

if [[ -z $APP_TYPE ]]; then
	echo "未指定APP_TYPE"
	exit 1
fi

# 根据命名规则确定参数
export TASK="${JOB_NAME#*/}"
export ENV=$(echo ${JOB_NAME%%/*} | cut -d "." -f 2)
export PROJECT=$(echo ${JOB_NAME%%/*} | cut -d "." -f 1)
export BUILD_TAG=$(date +"%Y%m%d")_${BUILD_NUMBER}

# 个性化不同应用参数
if [[ $APP_TYPE == java ]]; then
	if [[ $TYPE_VERSION != v1.8 ]]; then
		echo "不支持的$APP_TYPE TYPE_VERSION: $TYPE_VERSION"
		exit 1
	fi
	if [[ -z $BUILD_PATH ]]; then
		export BUILD_PATH="${DEFAULT_BUILD_PATH}"
	fi
	if [[ -z $TARGET_PATH ]]; then
		export TARGET_PATH="${DEFAULT_JAVA_TARGET_PATH}"
	fi
	if [[ -z $BUILD_COMMAND ]]; then
		export BUILD_COMMAND="${DEFAULT_BUILD_COMMAND_JAVA}"
	fi
	if [[ -z $Dockerfile_CMD ]]; then
		export Dockerfile_CMD="${DEFAULT_RUNNING_COMMAND_JAVA}"
	fi
	export JAVA_OPTIONS=$JAVA_OPTIONS

elif [[ $APP_TYPE == node ]]; then
	if [[ $TYPE_VERSION == v14 ]]; then
		if [[ -z $BUILD_COMMAND ]]; then
			export BUILD_COMMAND="${DEFAULT_BUILD_COMMAND_NODE_v14}"
		fi
	elif [[ $TYPE_VERSION == v16 ]]; then
		if [[ -z $BUILD_COMMAND ]]; then
			export BUILD_COMMAND="${DEFAULT_BUILD_COMMAND_NODE_v16}"
		fi
	else
		echo "不支持的$APP_TYPE TYPE_VERSION: $TYPE_VERSION"
		exit 1
	fi
	if [[ -z $BUILD_PATH ]]; then
		export BUILD_PATH="${DEFAULT_BUILD_PATH}"
	fi
	if [[ -z $Dockerfile_CMD ]]; then
		export Dockerfile_CMD="${DEFAULT_RUNNING_COMMAND_FRONTEND}"
	fi

elif [[ $APP_TYPE == python ]]; then
	export BUILD_COMMAND="${DEFAULT_BUILD_COMMAND_PYTHON}"
	if [[ -z $Dockerfile_CMD ]]; then
		export Dockerfile_CMD="${DEFAULT_RUNNING_COMMAND_PYTHON}"
	fi
fi

# 通用参数
COMMON_VARS="-e app_type=\"'${APP_TYPE}'\" -e type_version=\"'${TYPE_VERSION}'\" -e env=\"'${ENV}'\" -e task=\"'${TASK}'\" -e project=\"'${PROJECT}'\" -e workspace=\"'${WORKSPACE}'\" -e build_path=\"'${BUILD_PATH}'\" -e build_command=\"'${BUILD_COMMAND}'\" -e build_tag=\"'${BUILD_TAG}'\""
if [[ ${Dockerfile_EXTRA} == "" ]]; then
	Dockerfile_EXTRA="#"
fi
COMMON_VARS="${COMMON_VARS} -e Dockerfile_extra=\"'${Dockerfile_EXTRA}'\" -e Dockerfile_cmd=\"'${Dockerfile_CMD}'\""

# java应用
function build_java() {
	EXTRA_VARS="${COMMON_VARS} -e target_path=\"'${TARGET_PATH}'\""
	cmd="ANSIBLE_STDOUT_CALLBACK=yaml ansible-playbook -v ansible/playbook.yaml ${EXTRA_VARS} -e action=build"
	echo $cmd
	eval $cmd
}

# 前端应用
function build_node() {
	EXTRA_VARS="${COMMON_VARS}"
	cmd="ANSIBLE_STDOUT_CALLBACK=yaml ansible-playbook -v ansible/playbook.yaml ${EXTRA_VARS} -e action=build"
	echo $cmd
	eval $cmd
}

# python应用
function build_python() {
	EXTRA_VARS="${COMMON_VARS}"
	cmd="ANSIBLE_STDOUT_CALLBACK=yaml ansible-playbook -v ansible/playbook.yaml ${EXTRA_VARS} -e action=build"
	echo $cmd
	eval $cmd
}

# 通用应用
function build_app() {
	cmd="ANSIBLE_STDOUT_CALLBACK=yaml ansible-playbook -v ansible/playbook.yaml ${COMMON_VARS} -e action=build"
	echo $cmd
	eval $cmd
}

# 部署
function deploy_app() {
	# 检查可部署类型
	if [[ $DEPLOY_TYPE != kubernetes && $DEPLOY_TYPE != docker-compose && $DEPLOY_TYPE != resource ]]; then
		echo "不支持的部署类型DEPLOY_TYPE: $DEPLOY_TYPE"
		exit 2
	fi
	cmd="ANSIBLE_STDOUT_CALLBACK=yaml ansible-playbook -v ansible/playbook.yaml ${COMMON_VARS} -e action=deploy -e deploy_type=${DEPLOY_TYPE}"
	echo $cmd
	eval $cmd
}

# 发送通知
function notice_task() {
	if [[ ${currentResult} == "SUCCESS" ]]; then
		current_result="成功"
	elif [[ ${currentResult} == "FAILURE" ]];then
		current_result="失败"
	elif [[ ${currentResult} == "ABORTED" ]];then
		current_result="中止"
	else
		current_result="未知"
	fi
	if [[ ${action} == "build" ]]; then
		run_action="构建"
	elif [[ ${action} == "deploy" ]]; then
		run_action="部署"
	fi
	EXTRA_VARS="${COMMON_VARS} -e build_url=\"'${BUILD_URL}'\" -e job_name=\"'${JOB_NAME}'\" -e full_displayname=\"'${fullDisplayName}'\" -e build_user=\"'${BUILD_USER}'\" -e duration_string=\"'${durationString%% and counting}'\" -e current_result=\"'${current_result}'\" -e run_action=${run_action} -e code_url=${CODE_URL} -e branch=${BRANCH} -e NOTICE=${NOTICE} -e instruction=${INSTRUCTION}"
	cmd="ANSIBLE_STDOUT_CALLBACK=yaml ansible-playbook -v ansible/playbook.yaml ${EXTRA_VARS} -e action=notice"
	echo $cmd
    eval $cmd
}


case "$1" in
	build)
		case "$APP_TYPE" in
			java)
				eval build_java
				;;
			node)
				eval build_node
				;;
			python)
				eval build_python
				;;
			app)
				eval build_app
				;;
			*)
				echo "不支持的APP_TYPE: $APP_TYPE"
				exit 1
				;;
		esac
		;;
	deploy)
		eval deploy_app
		;;
	notice)
		eval notice_task
		;;
	*)
		echo "usage: "
		echo "  bash run.sh [build|deploy|notice]"
		exit 1
		;;
esac

