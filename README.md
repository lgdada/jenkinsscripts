# 软件要求
- ansible
- ansible-playbook
- docker
- git


# 脚本目录结构
```
.
├── ansible
│   ├── config.yaml                # ------------- 项目配置文件
│   ├── dockerfiles                # ------------- 构建镜像的dockerfile，文件命名规则 Dockerfile-[app_type]-[app_version]
│   ├── files                      # ------------- 发布应用相关的配置文件，通过config.yaml配置指定文件名或目录
│   │   ├── test_harbor
│   │   │   └── config.json        # ------------- 镜像仓库授权文件，用于上传镜像认证
│   │   │   └── config-readonly.json # ------------- 配置了只读仓库用户，用于docker-compose和resource发布方式拉取非公开镜像
│   │   ├── test_id_rsa            # ------------- 远程SSH的key文件
│   │   ├── settings.xml           # ------------- maven构建配置文件
│   │   ├── test_k8s_config        # ------------- k8s授权文件
│   ├── playbook.yaml              # ------------- 执行发布动作的入口
│   ├── scripts                    # ------------- 由playbook根据配置引入相应脚本
│   │   ├── build_docker_image.yaml
│   │   ├── build_java_image.yaml
│   │   ├── build.yaml
│   │   ├── deploy_common_resource.yaml
│   │   ├── deploy_docker-compose.yaml
│   │   ├── deploy_kubernetes_deployment.yaml
│   │   ├── deploy.yaml
│   │   └── notice_task.yaml
│   └── templates                  # ------------- playbook模板文件，生成docker-compose.yaml或playbook-deploy.yaml
│       ├── docker-compose-test.yaml.jinja
│       ├── playbook-deploy-common-resource.yaml.jinja
│       └── playbook-deploy-docker-compose.yaml.jinja
├── ansible.cfg
├── Jenkinsfile                    # ------------- jenkins发布首先执行的pipeline脚本
├── README.md
├── run.sh                         # ------------- 由jenkinsfile执行的动作脚本，生成command，执行playbook
└── update_Jenkinsfile             # ------------- 只用于运行一次构建，使所有jenkins任务的下游项目自动执行
```


# 脚本执行顺序
```
jenkinsfile --> 选择[action] --config--> unstable("【配置更新成功！】") ------------------------------------------------------------------> end
                      |                                                                                 |                              |
                      --------biuld---> run.sh build ---> run_build.sh(新生成) -------> run.sh notice -->                               |
                      |                                                                                                                |
                      ---deploy-->  run.sh build --> run_build.sh(新生成) --> run.sh deploy --> run_deploy.sh(新生成) -- run.sh notice ->
```

# 配置文件解析
__config.yaml__
```yaml
# 镜像仓库
register:
  [harbor]: # 定义镜像仓库名字
    url:    # 镜像仓库地址
    config: # 选择files下的目录名，目录下包含config.json配置

# 通知机器人
notice_api:
  [test_robot]: # 定义机器人名字
    type: # 目前支持 dingding 和 feishu
    url:  # 机器人webhook地址

# app类型配置定义
[java]: # app类型，支持java，node，python
  repo_dir: # maven在jenkins服务器上的缓存目录，用于java打包时挂载容器，(只用于java应用)
  [v1.8]:  # 可用版本
    build_image: # 构建时使用的镜像(python应用除外)
    base_image:  # 应用基础镜像，放打包完成的文件

# 项目配置
project_conf:
  [project_env]:  # 项目名称，格式为“项目_环境”，与jenkins项目文件夹名称类似，只是jenkins上格式为“项目.环境”
    notice: true  # 是否发通知，如果设置为false，notice_api配置忽略
    notice_api:   # 选择通知机器人名字(前面已定义的)
    register:     # 选择镜像仓库名字(前面已定义的)
    register_subpath: # 镜像仓库子目录名称，要在镜像仓库提前配置
    deploy:       # 是否允许执行部署，优先于action值；如果设置为false，后面的配置可以忽略
    # 发布应用到不同类型的环境
    # 发布到k8s
    kubernetes:   # 要求jenkins的task任务名与k8s的deployment名字一致
      config:     # 选择files目录下的k8s授权文件名
      namespace:  # 要发布deployment所在的namespace
      kubectl: kubectl:1.21  # 调用kubectl命令
    # 发布到docker
    docker-compose:
      ansible_host: # 通过ansible更新镜像，过程为 jenkins --执行ansible-playbook--> ansible_host --执行ssh -c命令--> target_host
      # 要求jenkins要有ansible_host的key，ansible_host能够免认证连接target_host
        ip: ssh_ip
        port: ssh_port
        user: root
        key:      # 选择files目录下的ssh key文件
      apps:
        [app_name]:  # 定义应用名称，要求与jenkins的task任务名一致
          service_template: # 选择templates目录下的docker-compse模板，用于应用的运行定义文件
          workpath: # 目标主机的总应用工作目录
          # 定义好路径后，应用该工作目录为【workpath/app_name】，新生成的运行文件命名为docker-compose-[build_number].yaml，并生成软链接到docker-compose.yaml
          hosts:  # 目标主机列表
            - xxx
            - bbb
    # 以更新文件形式发布
    resource:
      ansible_host:
        ip: ssh_ip
        port: ssh_port
        user: root
        key:
      apps:
        [app_name]:
          docker_resource_path: # 镜像内资源位置，用于复制到主机上
          reload_command: "xxx"   # 设置应用重启命令，使更新生效
          workpath: # 目标主机的总应用工作目录
          # 定义好路径后，应用该工作目录为【workpath/app_name】，并在工作目录下生成新目录app_name-[build_number]用于放从镜像复制出的文件，并生成软链接到app_name
          hosts:
            - xxx
```