## Fixed Personetics Assignment
### The repo contains the following elements
1. At root level spring-boot ``perso-greet`` project (***info only*** ~~[tutorial](https://spring.io/guides/gs/serving-web-content/)~~ ) 
   * Maven project - build using `mvn clean package`
   * [Dockerfile](https://docs.docker.com/engine/reference/builder/) - Packaging this project in Image  
   * [Jenkinsfile](https://www.jenkins.io/doc/book/pipeline/#pipeline-1) - CI/CD for this project  
2. helm-package ([helm](https://helm.sh/))
   * Contains greet chart - basic web helm package to wrap the docker image container for k8s deployment
   * Dockerfile_helm - docker image for building the helm package  
3. deployment folder ([ansible](https://docs.ansible.com/ansible/2.9/user_guide/index.html))
   * containing ansible(v2.9) playbooks and roles 
     - Setup the Jesnkins Master server
     - Setup the k8s ([k3s](https://k3s.io/)) deployment server
     - Deploying the app via helm to k8s ([k3s](https://k3s.io/))
     - Checking remote access to service 
4. environment folder 
   * Containing the info to access both servers 

### Full Deployment Steps
**There are 2 ec2 servers, one for the Jenkins Master and one for the k8s deployment.
  Their access information resides in the environment folder - connect to them with the default ec2-user username.
  Make sure the content of the inventory file `deployment/inventory` is updated with the correct access information.**
1. ***Setting up the environments***
   1. Install Ansible on one of the servers (or any other server you desire)
   2. Clone this repository to the server
   3. While in the repo folder, run the script `deployment/execute_plays.sh`
2. ***Setting up the Jenkins Master***
   * Access the Jenkins Master using the url `http://<jenkins_master_ip>:8080`
   * Install the plugins `Pipeline Utility Steps` and `Multibranch Scan Webhook Trigger` by going to `Manage Jenkins > Manage Plugins > available` and searching for them in the filter bar.
   * **Create a Multibranch pipeline**
     1. In the dashboard click on `New Item` and select `Multibranch Pipeline`
     2. In the `Branch Sources` tab choose git as source and add your repository url, in addition create a new `SSH Username with private key` Credential (for the ansible playbook tasks) and add to it your username and the private key that resides in the file `environment/skey`
    ![image](https://user-images.githubusercontent.com/82955780/209578840-a56b311c-0676-4269-866f-b8173e84bfa3.png)
     3. In the `Scan Multibranch Pipeline Triggers`tab you are going to connect a webhook to your repo. pick the `Scan by webhook` option and name your token, click on the question mark next to it and it will give you the url for the webhook.
![image](https://user-images.githubusercontent.com/82955780/209579360-306a38c4-6390-4563-818d-c364abc12965.png)
     4. In order to complete the webhook setup, go to your git VCS, in the repo settings click on `Webhooks` and create a new one, in the url put the url given from the last section. 
     5. Back to the Jenkins Multibranch pipeline creation , click on Apply and Save.
   * **Setting up the SMTP mailing**
     - From the Jenkins dashboard go to `Manage Jenkins > Configure System`
     - Scroll down until you reach `Extended E-mail Notification` section, fill the right SMTP server and port (for gmail - smtp.gmail.com , port - 465), Add a Username and password credential for your email, note that the username should be your email address. check the box of `use SSL`, fill the rest as you desire and save.
![image](https://user-images.githubusercontent.com/82955780/209580609-d4e77281-4cc7-4480-bf13-fcc58fd355c7.png)
3. Your pipeline is now ready, you can click on `Build now` to run the Jenkinsfile and deploy the app. it will also starting building automatically whenever a new commit is pushed due to the webhook.
***Please note that you might need to approve certain scripts on the first build of the pipeline, by going to `Manage Jenkins > In-process Script Approval` and approving the prompted scripts***



## Errors I encountered and how I fixed them
1. **readMavenPom error**
   * ***Error*** - On the first stage of the pipeline - conf. Jenkins didn't recognize the command `readMavenPom`
   ![image](https://user-images.githubusercontent.com/82955780/209581835-94275e39-c9b5-4238-a490-2caec71c7977.png)
   * ***Solution*** - I searched the issue online and found out I need to install the plugin `Pipeline Utility Steps`
2. **Scripts not permitted error**
   * ***Error*** - While running the Jenkinsfile for the first time I encountered the following error: "Scripts not permitted to use staticMethod org.codehaus.groovy.runtime.DefaultGroovyMethods putAt java.lang.Object java.lang.String java.lang.Object."
   * ***Solution*** - I added the script signature to the approved scripts in Jenkins `In-process Script Approval` configuration.
3. **Build deployment image error**
   * ***Error*** - During the `build deployment image` stage, an error showed up stating it could not find the file `ansible_Dockerfile`.
   * ***Solution*** - I figured out that the correct name of the file is `Dockerfile_ansible` and changed it.
   ![image](https://user-images.githubusercontent.com/82955780/209582534-d8b3d2fd-c73b-40c2-87f7-492312058b32.png)
4. **env.HELM_PACKAGE error**
   * ***Error*** - During the "deploy" stage I encountered an error when trying to copy the helm package which was supposed to be located in the environment variable HELM_PACKAGE. 
   * ![image](https://user-images.githubusercontent.com/82955780/209582828-0747dfff-e4a0-42cb-9389-6b2d199308a2.png)
   * ***Solution*** - I realised this environment variable wasn't initiated anywhere in the Jenkisfile and created it in the "helm package" stage.
   ![image](https://user-images.githubusercontent.com/82955780/209582916-d5103426-9836-4de5-abbe-bc789b95496f.png)
5. **Load docker image error**
   * ***Error*** - In the "deploy" stage while running the "deploy_app_to_k3s.yml" playbook, the task "Load docker image to crio-engine" failed with the error:
["ctr: open greet-demo/perso-greet:master.3.tar: no such file or directory"].
   * ***Solution*** - I checked manually in the deployment server where did `greet-demo/perso-greet:master.3.tar` got copied to and realised I needed to change the destination of the copy in the playbook to `project_path/image` instead of just `image`.
   ![image](https://user-images.githubusercontent.com/82955780/209583554-6f212b68-c5db-4243-ab96-dd337d123009.png)
6. **Helm Chart Deployment file error**
   * ***Error*** - In the "deploy" stage while running the "deploy_app_to_k3s.yml" playbook, the task "helm install" failed with the error: 
   Error: UPGRADE FAILED: failed to create resource: Deployment in version \"v1\" cannot be handled as a Deployment: json: cannot unmarshal array into Go struct field PodSpec.spec.template.spec.nodeSelector of type map[string]string"
   * ***Solution*** - I realised the problem is with the deployment file and that it's connected to the nodeSelector, I saw in the deployment file that the nodeSelector is getting a value from the `values.yaml` file, I checked the values file and saw that nodeSelector is set to an invalid type value and changed it.
   ![image](https://user-images.githubusercontent.com/82955780/209583870-e834bf7e-c4a5-4870-8c03-25269ccc8595.png)



