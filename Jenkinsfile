pipeline {

    agent any

    options {
        ansiColor('xterm')
        disableConcurrentBuilds()
    }

    stages {
        // Stage conf to setup environment variable for build
        stage("conf") {
            steps {
                script {
                    def pom = readMavenPom file: 'pom.xml'
                    env['PROJ'] = pom.artifactId
                    env['PROJ_PATH'] = "greet-demo"
                    def inventory = readFile file: 'deployment/inventory'
                    def get_ip = "${inventory}" =~ /(?sm).*k3s ansible_host=((?:(?:\d+)\.?){4}).*/
                    env['SERVER_IP'] = get_ip[0][1]
                    // Remove matcher object so it wont be serialized at the end of scope
                    // And a cps exception will be thrown
                    get_ip = null
                    sh 'env'
                }
            }
        }
        // Building the artifacts
        stage("build") {
            agent {
                docker {
                    image "maven:3-jdk-8-slim"
                    reuseNode true
                    args "-v \$HOME/.m2:/root/.m2"
                }
            }
            steps {
                sh 'mvn --version'
                sh 'mvn clean install -ntp -B -e'
            }
        }

        // building the image locally
        stage("build img") {
            steps {
                script {
                    env["IMAGE"] = "${env.PROJ}:${env.BRANCH_NAME}.${env.BUILD_ID}"
                    docker.build(env["IMAGE"])
                    sh "docker save -o deployment/${env.IMAGE}.tar ${env.IMAGE}"
                    //TODO check if relevant
                    env["ABS_IMAGE_PATH"] = "${env.WORKSPACE}/deployment/${env.IMAGE}.tar"
                }
            }
        }

        // building and packaging the helm package locally
        stage("helm package") {
            agent {
                dockerfile {
                    filename 'Dockerfile_helm'
                    dir 'helm-package'
                    reuseNode true
                }
            }
            steps {
                script {
                    sh 'helm lint helm-package/greet'
                    sh 'helm package helm-package/greet -u'
                    env['HELM_PACKAGE'] = "greet-0.1.0.tgz"
                    def chart_yaml = readYaml file: 'helm-package/greet/Chart.yaml'

                }
            }
        }

        stage("build deployment image") {
            steps {
                script {
                    env['DEP_IMAGE'] = "ansible_dep:${env.BUILD_ID}"
                    def dockerfile = 'deployment/Dockerfile_ansible'
                    docker.build("${env.DEP_IMAGE}", "-f ${dockerfile} .")
                }
            }
        }

        // deploying app when on release branches
        stage("deploy") {
            agent {
                docker {
                    image "${env.DEP_IMAGE}"
                    reuseNode true
                }
            }
            steps {
                dir("deployment") {
                    echo "copy package"
                    sh "cp ../${env.HELM_PACKAGE} ."
                    sh 'ls -la'
                }
                ansiblePlaybook(
                        playbook: 'deployment/deploy_app_to_k3s.yml',
                        inventory: 'deployment/inventory',
                        colorized: true,
                        disableHostKeyChecking: true,
                        credentialsId: 'test-key',
                        extras: "-e image=${env.IMAGE} " +
                                "-e project_name=${env.PROJ} " +
                                "-e project_path=${env.PROJ_PATH} " +
                                "-e helm_package=${env.HELM_PACKAGE} " +
                                "-e replica_count=2 " +
                                "-e service_port=8080 " +
                                "-e greeted=Jhon " +
                                "-vv"
                )
            }
        }

        stage("remote test") {
            agent {
                docker {
                    image "${env.DEP_IMAGE}"
                    reuseNode true
                }
            }
            steps {
                script {
                    ansiblePlaybook(playbook: 'deployment/get_service_port.yml',
                            inventory: 'deployment/inventory',
                            colorized: true,
                            disableHostKeyChecking: true,
                            credentialsId: 'test-key',
                            extras: "-e project_name=${env.PROJ} " +
                                    "-e file_path=node_port.txt " +
                                    "-vv")
                    def node_port = readFile file: "deployment/node_port.txt"
                    sh """ curl -L -D - "http://${env.SERVER_IP}:${node_port.trim()}/greeting?name=katsok" """
                }
            }
        }
    }
    post {
        always {
            script {
                def status = "${env.BUILD_TAG} - ${currentBuild.currentResult}"
                def body = """
                Build: ${currentBuild.displayName}
                Result: ${currentBuild.currentResult}
                """
                mail body: body, subject: status, to: 'orizadok5@gmail.com'
                mail body: body, subject: status, to: 'orizadok1@gmail.com'

                if (fileExists("deployment/${env.IMAGE}.tar")) {
                    sh "rm deployment/${env.IMAGE}.tar"
                }
                if (fileExists("deployment/${env.HELM_PACKAGE}")) {
                    sh "rm deployment/${env.HELM_PACKAGE}"
                }
            }
        }
    }
}
